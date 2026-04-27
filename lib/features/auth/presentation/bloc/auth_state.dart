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

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final bool isPremium;
  const AuthAuthenticated(this.user, {this.isPremium = false});
  @override
  List<Object?> get props => [user, isPremium];
}
