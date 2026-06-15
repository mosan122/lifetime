// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gotrue/gotrue.dart' as gotrue;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthUser;

import '../../../../core/failures/failure.dart';
import '../../../../core/services/google_drive_reauth_bridge.dart';
import '../../../../core/services/google_sign_in_silent.dart';
import '../../../../core/services/premium_service.dart';
import '../../data/datasources/auth_local_persistence.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/auth_session_policy.dart';
import '../../../profile/data/datasources/user_profile_local_datasource.dart';
import '../../../profile/domain/entities/user_profile_details.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../injection_container.dart';
import '../../../sync/schedule_cloud_sync.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._authRepository,
    this._premiumService,
    this._profileRepository,
    this._supabase,
    this._persistence,
    this._userProfileLocal,
    this._driveReauthBridge,
  ) : super(const AuthUnauthenticated()) {
    _driveReauthBridge.onReauthRequired = markRequiresGoogleReauth;
  }

  final AuthRepository _authRepository;
  final PremiumService _premiumService;
  final ProfileRepository _profileRepository;
  final SupabaseClient _supabase;
  final AuthLocalPersistence _persistence;
  final UserProfileLocalDataSource _userProfileLocal;
  final GoogleDriveReauthBridge _driveReauthBridge;

  StreamSubscription<gotrue.AuthState>? _authSub;

  Future<bool> _googleDriveLinkedFor(String userId) async {
    final local = await _userProfileLocal.getByUserId(userId);
    return local?.googleDriveLinked ?? false;
  }

  Future<AuthAuthenticated> _buildAuthenticated({
    required AuthUser user,
    required bool isPremium,
    required bool needsOnboarding,
    bool? requiresGoogleReauth,
    bool? googleDriveLinked,
  }) async {
    var linked = googleDriveLinked ?? await _googleDriveLinkedFor(user.id);
    if (user.accessToken != null) {
      linked = true;
      await _userProfileLocal.patchGoogleDriveLink(
        userId: user.id,
        linked: true,
      );
    }
    final prev = state;
    final reauth = requiresGoogleReauth ??
        (prev is AuthAuthenticated ? prev.requiresGoogleReauth : false);
    return AuthAuthenticated(
      user,
      isPremium: isPremium,
      needsOnboarding: needsOnboarding,
      requiresGoogleReauth: reauth,
      googleDriveLinked: linked,
    );
  }

  AuthAuthenticated _authenticatedFrom(
    AuthAuthenticated base, {
    bool? isPremium,
    bool? requiresGoogleReauth,
    bool? googleDriveLinked,
  }) {
    return AuthAuthenticated(
      base.user,
      isPremium: isPremium ?? base.isPremium,
      needsOnboarding: base.needsOnboarding,
      requiresGoogleReauth:
          requiresGoogleReauth ?? base.requiresGoogleReauth,
      googleDriveLinked: googleDriveLinked ?? base.googleDriveLinked,
    );
  }

  void markRequiresGoogleReauth() {
    final s = state;
    if (s is! AuthAuthenticated || s.requiresGoogleReauth) return;
    emit(_authenticatedFrom(s, requiresGoogleReauth: true));
  }

  void clearRequiresGoogleReauth() {
    final s = state;
    if (s is! AuthAuthenticated || !s.requiresGoogleReauth) return;
    emit(_authenticatedFrom(s, requiresGoogleReauth: false));
  }

  /// Vincula Google solo para backup en Drive (usuarios email/Apple).
  Future<Either<Failure, Unit>> linkGoogleAccount() async {
    final s = state;
    if (s is! AuthAuthenticated) {
      return const Left(AuthFailure('No autenticado'));
    }

    final result = await _authRepository.linkGoogleAccountForDrive();
    return await result.fold<Future<Either<Failure, Unit>>>(
      (f) async => Left(f),
      (email) async {
        await _userProfileLocal.patchGoogleDriveLink(
          userId: s.user.id,
          linked: true,
          accountEmail: email,
        );
        googleSignInSessionCache.invalidate();
        emit(
          _authenticatedFrom(
            s,
            requiresGoogleReauth: false,
            googleDriveLinked: true,
          ),
        );
        onPremiumSessionStarted();
        if (sl.isRegistered<CloudSyncService>()) {
          unawaited(
            sl<CloudSyncService>().restoreMilestoneMediaFromDrive(force: true),
          );
        }
        return const Right(unit);
      },
    );
  }

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

  /// Prioriza `profiles` sobre metadatos OAuth para nombre y foto.
  AuthUser _authUserFromProfile(AuthUser session, UserProfileDetails? details) {
    if (details == null) return session;
    final dn = details.displayName.trim();
    final av = details.avatarUrl?.trim() ?? '';
    return AuthUser(
      id: session.id,
      email: session.email,
      displayName: dn.isNotEmpty ? dn : session.displayName,
      photoUrl: av.isNotEmpty ? av : null,
      accessToken: session.accessToken,
      emailVerified: session.emailVerified,
    );
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
        await _buildAuthenticated(
          user: AuthUser(
            id: cached.userId,
            email: cached.email,
            displayName: localProfile?.displayName,
            photoUrl: localProfile?.avatarUrl,
            accessToken: null,
            emailVerified: true,
          ),
          isPremium: cached.isPremiumCached,
          needsOnboarding: needsOnboarding,
          googleDriveLinked: localProfile?.googleDriveLinked,
        ),
      );
      if (cached.isPremiumCached) onPremiumSessionStarted();
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
        await _buildAuthenticated(
          user: _authUserFromProfile(user, details),
          isPremium: isPremium,
          needsOnboarding: needsOnboarding,
          googleDriveLinked: details?.googleDriveLinked,
        ),
      );
      if (isPremium) onPremiumSessionStarted();
    } else {
      await _premiumService.init();
      emit(
        await _buildAuthenticated(
          user: user,
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
          await _buildAuthenticated(
            user: _authUserFromProfile(s.user, details),
            isPremium: isPremium,
            needsOnboarding: needs,
            googleDriveLinked: details?.googleDriveLinked,
          ),
        );
        if (isPremium) onPremiumSessionStarted();
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
      // Tras guardar perfil, la fuente de verdad es `profiles.avatar_url` (no volver a OAuth).
      photoUrl: saved.avatarUrl,
      accessToken: s.user.accessToken,
      emailVerified: s.user.emailVerified,
    );
    emit(
      await _buildAuthenticated(
        user: updatedUser,
        isPremium: saved.isPremium,
        needsOnboarding: false,
        googleDriveLinked: saved.googleDriveLinked,
        requiresGoogleReauth: s.requiresGoogleReauth,
      ),
    );
    if (saved.isPremium) onPremiumSessionStarted();
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
      emit(_authenticatedFrom(s, isPremium: value));
    }
  }

  /// Simula la suscripción Premium: Isar, Supabase `profiles` y caché local.
  Future<Either<Failure, Unit>> activatePremium() async {
    final s = state;
    if (s is! AuthAuthenticated) {
      return const Left(AuthFailure('Inicia sesión para activar Premium'));
    }

    final result = await _profileRepository.setUserPremium(
      userId: s.user.id,
      isPremium: true,
    );

    return result.fold(
      Left.new,
      (_) async {
        await _premiumService.setPremium(true);
        await _persistence.save(
          userId: s.user.id,
          email: s.user.email,
          isPremiumCached: true,
          emailVerified: s.user.emailVerified,
        );
        emit(_authenticatedFrom(s, isPremium: true));
        scheduleCloudDataSync(forceResync: true);
        return const Right(unit);
      },
    );
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
