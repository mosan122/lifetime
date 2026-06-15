import 'package:googleapis/drive/v3.dart' as drive;

/// Error HTTP 401/403 de la API de Drive: requiere re-vincular Google.
class GoogleDriveAuthException implements Exception {
  const GoogleDriveAuthException(this.statusCode, [this.message]);

  final int statusCode;
  final String? message;

  @override
  String toString() =>
      'GoogleDriveAuthException($statusCode${message != null ? ': $message' : ''})';
}

bool isGoogleDriveAuthError(Object error) {
  if (error is GoogleDriveAuthException) return true;
  if (error is drive.DetailedApiRequestError) {
    final code = error.status ?? 0;
    return code == 401 || code == 403;
  }
  return false;
}

Never rethrowIfGoogleDriveAuthError(Object error) {
  if (error is drive.DetailedApiRequestError) {
    final code = error.status ?? 0;
    if (code == 401 || code == 403) {
      throw GoogleDriveAuthException(code, error.message);
    }
  }
  throw error;
}
