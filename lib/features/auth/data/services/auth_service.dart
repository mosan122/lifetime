import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/config/supabase_auth_config.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/services/auth_session_policy.dart';

class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

/// Infraestructura de autenticación (Supabase + Google + Apple).
class AuthService {
  AuthService(this._supabase, this._googleSignIn);

  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;

  static const _driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
  ];

  static const _googleScopeHint = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  bool get isAppleSignInSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);

  /// Registro email/contraseña (Supabase envía correo de verificación).
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: kSupabaseAuthRedirectUrl,
    );
  }

  Future<void> resendSignupEmail(String email) async {
    await _supabase.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  /// Login email/contraseña. Supabase suele responder `email_not_confirmed` si falta verificar.
  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Abre el flujo OAuth de Google (el resultado llega por deep link + `onAuthStateChange`).
  Future<bool> signInWithGoogleOAuth() async {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kSupabaseAuthRedirectUrl,
    );
  }

  /// Google nativo (`google_sign_in`) + sesión Supabase por id_token (útil si OAuth falla en algún dispositivo).
  Future<GoogleSignInAccount> signInWithGoogleNative() async {
    final account = await _googleSignIn.authenticate(scopeHint: _googleScopeHint);
    final idToken = account.authentication.idToken;
    if (idToken != null) {
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: null,
      );
    }
    return account;
  }

  /// Apple nativo + `signInWithIdToken` en Supabase.
  Future<void> signInWithAppleNative() async {
    if (!isAppleSignInSupported) {
      throw UnsupportedError('Sign in with Apple solo está disponible en iOS');
    }
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AuthException('No se recibió identityToken de Apple');
    }
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  /// Abre OAuth Apple en plataformas donde aplica (mismo patrón que Google).
  Future<bool> signInWithAppleOAuth() async {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kSupabaseAuthRedirectUrl,
    );
  }

  /// Espera a que exista sesión Supabase con email verificado (p. ej. tras OAuth + deep link).
  Future<bool> waitForVerifiedSession({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final u0 = _supabase.auth.currentUser;
    if (u0 != null && isSupabaseEmailVerified(u0)) return true;

    try {
      await _supabase.auth.onAuthStateChange
          .map((e) => e.session)
          .where(
            (s) =>
                s != null && isSupabaseEmailVerified(s.user),
          )
          .first
          .timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<AuthUser?> buildAuthUserFromSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null || !isSupabaseEmailVerified(user)) return null;

    String? accessToken;
    try {
      final g = await _googleSignIn.attemptLightweightAuthentication();
      if (g != null) {
        final auth = await g.authorizationClient.authorizeScopes(_driveScopes);
        accessToken = auth.accessToken;
      }
    } catch (_) {
      // Drive opcional hasta que el usuario autorice.
    }

    final meta = user.userMetadata ?? {};
    final given = (meta['given_name'] as String?)?.trim();
    final family = (meta['family_name'] as String?)?.trim();
    String? display = (meta['full_name'] as String?)?.trim() ??
        (meta['name'] as String?)?.trim();
    if ((display == null || display.isEmpty) &&
        given != null &&
        family != null) {
      display = '$given $family'.trim();
    } else if ((display == null || display.isEmpty) && given != null) {
      display = given;
    }
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: display,
      photoUrl: meta['avatar_url'] as String? ?? meta['picture'] as String?,
      accessToken: accessToken,
      emailVerified: true,
    );
  }

  /// Intenta obtener cuenta Google actual (tras OAuth puede enlazar la misma cuenta).
  Future<GoogleSignInAccount?> getGoogleAccount() async {
    if (_supabase.auth.currentUser == null) return null;
    try {
      return await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      return null;
    }
  }

  /// Vincula Google solo para Drive (sin cambiar la sesión Supabase email/Apple).
  Future<GoogleSignInAccount> linkGoogleAccountForDrive() async {
    if (_supabase.auth.currentUser == null) {
      throw const AuthException('No hay sesión activa en LifeTime');
    }
    final account = await _googleSignIn.authenticate(scopeHint: _driveScopes);
    await account.authorizationClient.authorizeScopes(_driveScopes);
    return account;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
