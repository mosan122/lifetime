import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_scope_auth.dart';
import 'google_drive_service.dart';
import 'google_sign_in_silent.dart';

/// Descarga puntual de un medio desde Drive sin abrir UI de Google por widget.
class MilestoneDriveMediaDownloader {
  MilestoneDriveMediaDownloader(this._googleSignIn);

  final GoogleSignIn _googleSignIn;
  final Map<String, Future<void>> _inFlight = {};

  Future<void> downloadIfMissing({
    required String driveFileId,
    required String localPath,
  }) async {
    final id = driveFileId.trim();
    final path = localPath.trim();
    if (id.isEmpty || path.isEmpty) return;
    if (File(path).existsSync()) return;

    final key = '$id|$path';
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _download(id, path);
    _inFlight[key] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _download(String driveFileId, String localPath) async {
    final account = await googleSignInSilently(_googleSignIn);
    if (account == null) return;

    final authorization = await driveAuthorizationSilently(account);
    if (authorization == null) return;

    try {
      await GoogleDriveService(_googleSignIn).downloadFile(driveFileId, localPath);
    } catch (_) {
      // Best-effort; la UI muestra placeholder.
    }
  }
}
