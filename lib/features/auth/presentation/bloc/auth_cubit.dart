// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/premium_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final PremiumService _premiumService;

  AuthCubit(this._authRepository, this._premiumService)
      : super(const AuthUnauthenticated());

  Future<void> checkCurrentUser() async {
    await _premiumService.init();
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthAuthenticating());
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (failure) => emit(AuthUnauthenticated(error: failure.message)),
      (user) => emit(
        AuthAuthenticated(user, isPremium: _premiumService.isPremium),
      ),
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
