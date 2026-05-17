import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_session_cache.dart';

/// Instancia compartida (también registrada en DI para invalidar al cerrar sesión).
final googleSignInSessionCache = GoogleSignInSessionCache();

/// Refresco silencioso de sesión Google (`google_sign_in` v7), con caché y
/// enfriamiento tras fallos para no abrir `HiddenActivity` en cada pantalla.
Future<GoogleSignInAccount?> googleSignInSilently(GoogleSignIn signIn) {
  return googleSignInSessionCache.getAccount(signIn);
}
