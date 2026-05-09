import 'package:dartz/dartz.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/failures/failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth);

  final AuthService _auth;

  @override
  Future<Either<Failure, Unit>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.registerWithEmail(email: email, password: password);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message ?? '', e.code));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> resendSignupEmail(String email) async {
    try {
      await _auth.resendSignupEmail(email);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message ?? '', e.code));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.loginWithEmail(email: email, password: password);
      final user = await _auth.buildAuthUserFromSession();
      if (user == null) {
        return const Left(
          AuthFailure('No se pudo iniciar sesión. Verifica tu correo.'),
        );
      }
      return Right<Failure, AuthUser>(user);
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        return const Left(
          AuthFailure(
            'Tu correo aún no está verificado. Revisa tu bandeja de entrada.',
            'email_not_confirmed',
          ),
        );
      }
      return Left(AuthFailure(e.message ?? '', e.code));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> beginGoogleOAuth() async {
    try {
      final ok = await _auth.signInWithGoogleOAuth();
      if (!ok) {
        return const Left(AuthFailure('No se pudo abrir el inicio de sesión con Google'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> beginAppleOAuth() async {
    try {
      final ok = await _auth.signInWithAppleOAuth();
      if (!ok) {
        return const Left(AuthFailure('No se pudo abrir el inicio de sesión con Apple'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> waitForOAuthSessionVerified({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final ok = await _auth.waitForVerifiedSession(timeout: timeout);
    if (!ok) {
      return const Left(
        AuthFailure(
          'No se completó el inicio de sesión. Si cancelaste, vuelve a intentarlo.',
        ),
      );
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AuthUser>> signInWithAppleNative() async {
    try {
      await _auth.signInWithAppleNative();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Left(AuthFailure('Inicio de sesión cancelado'));
      }
      return Left(AuthFailure(e.message ?? ''));
    } on UnsupportedError catch (e) {
      return Left(AuthFailure(e.message ?? ''));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message ?? '', e.code));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
    final user = await _auth.buildAuthUserFromSession();
    if (user == null) {
      return const Left(
        AuthFailure('No se pudo completar el inicio de sesión con Apple'),
      );
    }
    return Right<Failure, AuthUser>(user);
  }

  @override
  Future<AuthUser?> loadVerifiedUserFromSession() =>
      _auth.buildAuthUserFromSession();

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _auth.signOut();
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }
}
