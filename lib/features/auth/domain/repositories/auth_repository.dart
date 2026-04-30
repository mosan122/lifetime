import 'package:dartz/dartz.dart';
import '../../../../core/failures/failure.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthUser>> signInWithGoogle();
  Future<Either<Failure, Unit>> signOut();
  Future<AuthUser?> getCurrentUser();
}
