// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gotrue/gotrue.dart' as gotrue;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthUser;

import '../../../../core/failures/failure.dart';
import '../../../../core/services/premium_service.dart';
import '../../data/datasources/auth_local_persistence.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/auth_session_policy.dart';
import '../../../profile/data/datasources/user_profile_local_datasource.dart';
import '../../../profile/domain/entities/user_profile_details.dart';
import '../../../profile/domain/repositories/profile_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._authRepository,
    this._premiumService,
    this._profileRepository,
    this._supabase,
    this._persistence,
    this._userProfileLocal,
  ) : super(const AuthUnauthenticated());

  final AuthRepository _authRepository;
  final PremiumService _premiumService;
  final ProfileRepository _profileRepository;
  final SupabaseClient _supabase;
  final AuthLocalPersistence _persistence;
  final UserProfileLocalDataSource _userProfileLocal;

  StreamSubscription<gotrue.AuthState>? _authSub;

  /// Escucha Supabase (deep links OAuth, cierre de sesión remoto, etc.).
  void listenToSupabaseAuth() {
    _authSub?.cancel();
    _authSub =
        _supabase.auth.onAuthStateChange.listen((gotrue.AuthState data) async {
      switch (data.event) {
        case gotrue.AuthChangeEvent.initialSession:
        case gotrue.AuthChangeEvent.userUpdated:
          await _syncFromRemoteSession();
          break;
        case gotrue.AuthChangeEvent.signedOut:
          await _persistence.clear();
          emit(const AuthUnauthenticated());
          break;
        default:
          break;
      }
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }

  Future<void> checkCurrentUser() async {
    final supa = _supabase.auth.currentUser;
    if (supa != null) {
      await _syncFromRemoteSession();
      return;
    }

    final cached = await _persistence.read();
    if (cached != null && cached.emailVerified) {
      await _premiumService.setPremium(cached.isPremiumCached);
      final localProfile = await _userProfileLocal.getByUserId(cached.userId);
      final needsOnboarding = localProfile == null ||
          localProfile.displayName.trim().isEmpty;
      emit(
        AuthAuthenticated(
          AuthUser(
            id: cached.userId,
            email: cached.email,
            displayName: localProfile?.displayName,
            photoUrl: localProfile?.avatarUrl,
            accessToken: null,
            emailVerified: true,
          ),
          isPremium: cached.isPremiumCached,
          needsOnboarding: needsOnboarding,
        ),
      );
      _refreshProfileInBackground(cached.userId, cached.email);
      return;
    }

    emit(const AuthUnauthenticated());
  }

  Future<void> _syncFromRemoteSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    if (!isSupabaseEmailVerified(user)) {
      emit(AuthPendingVerification(user.email ?? ''));
      return;
    }
    await _finalizeAuthenticatedFlow(
      await _authRepository.loadVerifiedUserFromSession(),
    );
  }

  Future<void> _finalizeAuthenticatedFlow(AuthUser? user) async {
    if (user == null) {
      emit(const AuthUnauthenticated(
        error: 'No se pudo obtener el perfil de usuario',
      ));
      return;
    }

    final supaId = _supabase.auth.currentUser?.id;
    final hadCachedBefore = (await _persistence.read()) != null;

    if (supaId != null) {
      final upsert = await _profileRepository.upsertProfileAfterLogin(
        userId: supaId,
        email: user.email,
      );
      if (!hadCachedBefore && upsert.isLeft()) {
        emit(const AuthUnauthenticated(
          error: 'Se requiere conexión para el primer registro',
        ));
        return;
      }

      final profileRes = await _profileRepository.fetchUserProfile(
        userId: supaId,
        emailFallback: user.email,
      );
      final details = profileRes.fold((_) => null, (d) => d);
      final isPremium = details?.isPremium ?? false;
      final needsOnboarding = details?.needsOnboarding ?? true;

      await _premiumService.setPremium(isPremium);
      await _persistence.save(
        userId: supaId,
        email: user.email,
        isPremiumCached: isPremium,
        emailVerified: true,
      );
      if (details != null && !details.needsOnboarding) {
        await _userProfileLocal.put(details);
      }

      emit(
        AuthAuthenticated(
          user,
          isPremium: isPremium,
          needsOnboarding: needsOnboarding,
        ),
      );
    } else {
      await _premiumService.init();
      emit(
        AuthAuthenticated(
          user,
          isPremium: _premiumService.isPremium,
          needsOnboarding: true,
        ),
      );
    }
  }

  Future<void> _refreshProfileInBackground(String userId, String email) async {
    try {
      await _profileRepository.upsertProfileAfterLogin(
        userId: userId,
        email: email,
      );
      final profileRes = await _profileRepository.fetchUserProfile(
        userId: userId,
        emailFallback: email,
      );
      final details = profileRes.fold((_) => null, (d) => d);
      final isPremium = details?.isPremium ?? _premiumService.isPremium;
      await _premiumService.setPremium(isPremium);
      final cached = await _persistence.read();
      if (cached != null && cached.userId == userId) {
        await _persistence.save(
          userId: userId,
          email: email,
          isPremiumCached: isPremium,
          emailVerified: true,
        );
      }

      final s = state;
      if (s is AuthAuthenticated && s.user.id == userId) {
        final needs = details?.needsOnboarding ?? s.needsOnboarding;
        if (details != null && !details.needsOnboarding) {
          await _userProfileLocal.put(details);
        }
        emit(
          AuthAuthenticated(
            s.user,
            isPremium: isPremium,
            needsOnboarding: needs,
          ),
        );
      }
    } catch (_) {
      // offline
    }
  }

  /// Guarda perfil (onboarding o edición) en Supabase + Isar y actualiza sesión local.
  Future<Either<Failure, Unit>> saveUserProfile({
    required UserProfileDetails details,
    Uint8List? newAvatarBytes,
  }) async {
    final s = state;
    if (s is! AuthAuthenticated) {
      return const Left(AuthFailure('No autenticado'));
    }

    final result = await _profileRepository.saveUserProfile(
      details: details,
      newAvatarBytes: newAvatarBytes,
    );

    Failure? failSide;
    UserProfileDetails? okSide;
    result.fold((l) => failSide = l, (r) => okSide = r);
    if (failSide != null) {
      return Left(failSide!);
    }
    final saved = okSide;
    if (saved == null) {
      return const Left(AuthFailure('No se pudo guardar el perfil'));
    }

    await _userProfileLocal.put(saved);
    await _premiumService.setPremium(saved.isPremium);
    await _persistence.save(
      userId: saved.userId,
      email: saved.email,
      isPremiumCached: saved.isPremium,
      emailVerified: true,
    );
    final updatedUser = AuthUser(
      id: s.user.id,
      email: saved.email.isNotEmpty ? saved.email : s.user.email,
      displayName:
          saved.displayName.trim().isEmpty ? null : saved.displayName.trim(),
      photoUrl: saved.avatarUrl ?? s.user.photoUrl,
      accessToken: s.user.accessToken,
      emailVerified: s.user.emailVerified,
    );
    emit(
      AuthAuthenticated(
        updatedUser,
        isPremium: saved.isPremium,
        needsOnboarding: false,
      ),
    );
    return const Right(unit);
  }

  Future<Either<Failure, Unit>> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _authRepository.registerWithEmail(email: email, password: password);
  }

  Future<Either<Failure, Unit>> resendSignupEmail(String email) {
    return _authRepository.resendSignupEmail(email);
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emit(const AuthAuthenticating());
    final result = await _authRepository.loginWithEmail(
      email: email,
      password: password,
    );
    await result.fold(
      (failure) async {
        if (failure is AuthFailure && failure.code == 'email_not_confirmed') {
          emit(AuthPendingVerification(email));
        } else {
          emit(AuthUnauthenticated(error: failure.message));
        }
      },
      (user) async {
        await _finalizeAuthenticatedFlow(user);
      },
    );
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthAuthenticating());
    final launched = await _authRepository.beginGoogleOAuth();
    await launched.fold(
      (f) async => emit(AuthUnauthenticated(error: f.message)),
      (_) async {},
    );
    if (state is AuthUnauthenticated) return;

    final waited = await _authRepository.waitForOAuthSessionVerified();
    await waited.fold(
      (f) async => emit(AuthUnauthenticated(error: f.message)),
      (_) async {
        await _finalizeAuthenticatedFlow(
          await _authRepository.loadVerifiedUserFromSession(),
        );
      },
    );
  }

  Future<void> signInWithApple() async {
    emit(const AuthAuthenticating());
    final result = await _authRepository.signInWithAppleNative();
    await result.fold(
      (f) async => emit(AuthUnauthenticated(error: f.message)),
      (user) async => _finalizeAuthenticatedFlow(user),
    );
  }

  Future<void> signInWithAppleOAuth() async {
    emit(const AuthAuthenticating());
    final launched = await _authRepository.beginAppleOAuth();
    await launched.fold(
      (f) async => emit(AuthUnauthenticated(error: f.message)),
      (_) async {},
    );
    if (state is AuthUnauthenticated) return;

    final waited = await _authRepository.waitForOAuthSessionVerified();
    await waited.fold(
      (f) async => emit(AuthUnauthenticated(error: f.message)),
      (_) async {
        await _finalizeAuthenticatedFlow(
          await _authRepository.loadVerifiedUserFromSession(),
        );
      },
    );
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    await _persistence.clear();
    emit(const AuthUnauthenticated());
  }

  Future<void> setPremium(bool value) async {
    await _premiumService.setPremium(value);
    final s = state;
    if (s is AuthAuthenticated) {
      emit(AuthAuthenticated(
        s.user,
        isPremium: value,
        needsOnboarding: s.needsOnboarding,
      ));
    }
  }

  Future<void> refreshAfterEmailVerification() async {
    await _syncFromRemoteSession();
  }

  void clearError() {
    if (state is AuthUnauthenticated) {
      emit(const AuthUnauthenticated());
    }
  }
}
