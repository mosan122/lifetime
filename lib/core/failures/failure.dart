import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication error', String? code])
      : super(message, code: code);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(String message, {String? code})
      : super(message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error', String? code])
      : super(message, code: code);
}

class BiographerFailure extends Failure {
  const BiographerFailure([String message = 'Biographer service error', String? code])
      : super(message, code: code);
}
