import 'package:supabase_flutter/supabase_flutter.dart';

/// URL de retorno tras verificación de email u OAuth (PKCE).
/// Debe coincidir con el intent-filter de Android (`com.mosan.lifetime` + host
/// `login`), CFBundleURLTypes en iOS y las Redirect URLs en Supabase
/// Dashboard → Authentication.
const String kSupabaseAuthRedirectUrl = 'com.mosan.lifetime://login';

/// Configuración del cliente GoTrue en Flutter: flujo PKCE y captura de sesión
/// desde el URI al abrir la app por deep link (`app_links`).
const FlutterAuthClientOptions kSupabaseFlutterAuthOptions =
    FlutterAuthClientOptions(
  authFlowType: AuthFlowType.pkce,
  detectSessionInUri: true,
);
