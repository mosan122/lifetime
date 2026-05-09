// lib/features/auth/presentation/bloc/auth_state.dart
part of 'auth_cubit.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthUnauthenticated extends AuthState {
  final String? error;
  const AuthUnauthenticated({this.error});
  @override
  List<Object?> get props => [error];
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

/// Hay sesión Supabase pero el correo aún no está confirmado.
class AuthPendingVerification extends AuthState {
  final String email;
  const AuthPendingVerification(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final bool isPremium;
  /// `true` si falta `display_name` en `profiles` (onboarding obligatorio).
  final bool needsOnboarding;

  const AuthAuthenticated(
    this.user, {
    this.isPremium = false,
    this.needsOnboarding = false,
  });

  @override
  List<Object?> get props => [user, isPremium, needsOnboarding];
}
