// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/premium_service.dart';
import '../../../profile/domain/repositories/profile_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final PremiumService _premiumService;
  final ProfileRepository _profileRepository;
  final SupabaseClient _supabase;

  AuthCubit(
    this._authRepository,
    this._premiumService,
    this._profileRepository,
    this._supabase,
  )
      : super(const AuthUnauthenticated());

  Future<void> checkCurrentUser() async {
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      final supaId = _supabase.auth.currentUser?.id;
      if (supaId != null) {
        final profile = await _profileRepository.fetchProfile(supaId);
        final isPremium = profile.fold((_) => false, (p) => p.isPremium);
        await _premiumService.setPremium(isPremium);
      } else {
        await _premiumService.init();
      }
      emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
    } else {
      emit(const AuthUnauthenticated());
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
        if (supaId != null) {
          final profile = await _profileRepository.fetchProfile(supaId);
          final isPremium = profile.fold((_) => false, (p) => p.isPremium);
          await _premiumService.setPremium(isPremium);
        } else {
          await _premiumService.init();
        }
        emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
      },
    );
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
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
