import 'package:gotrue/gotrue.dart' as gotrue;

/// Supabase marca verificación con `email_confirmed_at` (ISO8601).
bool isSupabaseEmailVerified(gotrue.User? user) {
  if (user == null) return false;
  final v = user.emailConfirmedAt;
  return v != null && v.trim().isNotEmpty;
}
