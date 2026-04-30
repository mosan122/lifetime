import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/failures/failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  static const _driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
  ];

  @override
  Future<Either<Failure, AuthUser>> signInWithGoogle() async {
    try {
      final account = await _dataSource.signInWithGoogle();
      final user = await _accountToUser(account);
      return Right(user);
    } on SignInCancelledException {
      return const Left(AuthFailure('Sign-in cancelled'));
    } on PlatformException catch (e) {
      return Left(AuthFailure(e.message ?? 'Google sign-in failed', e.code));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    try {
      final account = await _dataSource.getCurrentUser();
      if (account == null) return null;
      return _accountToUser(account);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> _accountToUser(GoogleSignInAccount account) async {
    // google_sign_in v7: accessToken comes from authorizationClient, not from
    // `account.authentication`.
    final authorization =
        await account.authorizationClient.authorizeScopes(_driveScopes);
    return AuthUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      accessToken: authorization.accessToken,
    );
  }
}
