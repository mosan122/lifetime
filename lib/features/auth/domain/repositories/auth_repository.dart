import 'package:dartz/dartz.dart';
import '../../../../core/failures/failure.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, Unit>> registerWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> resendSignupEmail(String email);

  Future<Either<Failure, AuthUser>> loginWithEmail({
    required String email,
    required String password,
  });

  /// Abre el navegador / ASWebSession para OAuth Google (PKCE + deep link).
  Future<Either<Failure, Unit>> beginGoogleOAuth();

  /// Igual que Google, para Apple en plataformas sin flujo nativo.
  Future<Either<Failure, Unit>> beginAppleOAuth();

  /// Espera sesión Supabase con email verificado tras OAuth.
  Future<Either<Failure, Unit>> waitForOAuthSessionVerified({
    Duration timeout = const Duration(minutes: 2),
  });

  /// Apple nativo (iOS).
  Future<Either<Failure, AuthUser>> signInWithAppleNative();

  Future<AuthUser?> loadVerifiedUserFromSession();

  Future<Either<Failure, Unit>> signOut();

  /// Google Sign-In interactivo solo para permisos de Drive.
  Future<Either<Failure, String>> linkGoogleAccountForDrive();
}
