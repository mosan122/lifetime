import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

abstract class AuthRemoteDataSource {
  Future<GoogleSignInAccount> signInWithGoogle();
  Future<void> signOut();
  Future<GoogleSignInAccount?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final GoogleSignIn _googleSignIn;
  final SupabaseClient _supabase;

  AuthRemoteDataSourceImpl(this._googleSignIn, this._supabase);

  static const _scopeHint = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  @override
  Future<GoogleSignInAccount> signInWithGoogle() async {
    late final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate(scopeHint: _scopeHint);
    } on Exception catch (e) {
      // google_sign_in v7 no longer returns null on cancel; treat failures as a
      // user-cancelled flow when possible.
      if (e is PlatformException && e.code == 'sign_in_canceled') {
        throw const SignInCancelledException();
      }
      rethrow;
    }

    // Establish a Supabase session so RLS-guarded queries can authenticate.
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken != null) {
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: null, // access token is obtained via authorizationClient in v7
      );
    }

    return account;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  @override
  Future<GoogleSignInAccount?> getCurrentUser() async {
    // Supabase restores its session from storage on init; check it first.
    if (_supabase.auth.currentUser != null) {
      return _googleSignIn.attemptLightweightAuthentication();
    }
    return null;
  }
}
