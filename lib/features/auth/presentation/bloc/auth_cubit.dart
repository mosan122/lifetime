// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/premium_service.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../../core/services/local_user_settings_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final PremiumService _premiumService;
  final ProfileRepository _profileRepository;
  final SupabaseClient _supabase;
  final LocalUserSettingsService _userSettings;

  AuthCubit(
    this._authRepository,
    this._premiumService,
    this._profileRepository,
    this._supabase,
    this._userSettings,
  )
      : super(const AuthUnauthenticated());

  Future<void> checkCurrentUser() async {
    // Local-first: if we have a cached user, enter the app immediately.
    final cached = await _userSettings.getCurrent();
    if (cached != null) {
      await _premiumService.setPremium(cached.isPremiumCached);
      emit(
        AuthAuthenticated(
          AuthUser(
            id: cached.userId,
            email: cached.email,
            displayName: null,
            photoUrl: null,
            accessToken: null,
          ),
          isPremium: cached.isPremiumCached,
        ),
      );

      // Background refresh: last_connection + is_premium (best-effort).
      _refreshProfileInBackground(cached.userId, cached.email);
      _refreshGoogleAccessTokenInBackground();
      return;
    }

    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      final supaId = _supabase.auth.currentUser?.id;
      if (supaId != null) {
        final profile = await _profileRepository.fetchProfile(supaId);
        final isPremium = profile.fold((_) => false, (p) => p.isPremium);
        await _premiumService.setPremium(isPremium);
        await _userSettings.save(
          userId: supaId,
          email: user.email,
          isPremiumCached: isPremium,
        );
      } else {
        await _premiumService.init();
      }
      emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _refreshProfileInBackground(String userId, String email) async {
    try {
      // Update last_connection but keep current is_premium.
      await _profileRepository.upsertProfileAfterLogin(userId: userId, email: email);
      final profile = await _profileRepository.fetchProfile(userId);
      final isPremium = profile.fold((_) => _premiumService.isPremium, (p) => p.isPremium);
      await _premiumService.setPremium(isPremium);
      final cached = await _userSettings.getCurrent();
      if (cached != null && cached.userId == userId) {
        await _userSettings.save(
          userId: userId,
          email: email,
          isPremiumCached: isPremium,
        );
      }

      final s = state;
      if (s is AuthAuthenticated && s.user.id == userId) {
        emit(AuthAuthenticated(s.user, isPremium: isPremium));
      }
    } catch (_) {
      // Ignore: offline should not block.
    }
  }

  Future<void> _refreshGoogleAccessTokenInBackground() async {
    try {
      final u = await _authRepository.getCurrentUser();
      if (u == null) return;
      final s = state;
      if (s is AuthAuthenticated && s.user.id == u.id) {
        emit(AuthAuthenticated(u, isPremium: s.isPremium));
      }
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthAuthenticating());
    final result = await _authRepository.signInWithGoogle();
    await result.fold(
      (failure) async {
        emit(AuthUnauthenticated(error: failure.message));
      },
      (user) async {
        final supaId = _supabase.auth.currentUser?.id;
        final hadCachedBefore = (await _userSettings.getCurrent()) != null;
        if (supaId != null) {
          // Upsert profile row (id/email/last_connection) without clobbering is_premium.
          final upsert = await _profileRepository.upsertProfileAfterLogin(
            userId: supaId,
            email: user.email,
          );
          // If user has never been registered and we have no internet, block with a clear message.
          if (!hadCachedBefore && upsert.isLeft()) {
            emit(const AuthUnauthenticated(
              error: 'Se requiere conexión para el primer registro',
            ));
            return;
          }

          final profile = await _profileRepository.fetchProfile(supaId);
          final isPremium = profile.fold((_) => false, (p) => p.isPremium);
          await _premiumService.setPremium(isPremium);
          await _userSettings.save(
            userId: supaId,
            email: user.email,
            isPremiumCached: isPremium,
          );
        } else {
          await _premiumService.init();
        }
        emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
      },
    );
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    await _userSettings.clear();
    emit(const AuthUnauthenticated());
  }

  Future<void> setPremium(bool value) async {
    await _premiumService.setPremium(value);
    final s = state;
    if (s is AuthAuthenticated) {
      emit(AuthAuthenticated(s.user, isPremium: value));
    }
  }
}
