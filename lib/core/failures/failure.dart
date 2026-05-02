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

class FaceCropCancelledFailure extends Failure {
  const FaceCropCancelledFailure() : super('Operación cancelada');
}

class FaceCropPickFailure extends Failure {
  const FaceCropPickFailure([String message = 'Error al seleccionar imagen'])
      : super(message);
}

class FaceCropSaveFailure extends Failure {
  const FaceCropSaveFailure([String message = 'Error al guardar foto de perfil'])
      : super(message);
}
