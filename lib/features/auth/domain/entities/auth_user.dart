import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? accessToken;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.accessToken,
  });

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, accessToken];
}
