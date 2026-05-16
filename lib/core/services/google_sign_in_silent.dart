import 'package:google_sign_in/google_sign_in.dart';

/// Refresco silencioso de sesión Google (`google_sign_in` v7).
///
/// En v7 no existe `signInSilently()`; equivale a
/// [GoogleSignIn.attemptLightweightAuthentication].
Future<GoogleSignInAccount?> googleSignInSilently(GoogleSignIn signIn) async {
  final attempt = signIn.attemptLightweightAuthentication();
  if (attempt == null) return null;
  return attempt;
}
