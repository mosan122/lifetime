import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_service.dart';

/// Token Drive sin UI. Devuelve `null` si el usuario aún no autorizó Drive.
Future<GoogleSignInClientAuthorization?> driveAuthorizationSilently(
  GoogleSignInAccount account,
) async {
  try {
    return await account.authorizationClient.authorizationForScopes(
      GoogleDriveService.driveScopes,
    );
  } catch (_) {
    return null;
  }
}
