import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'google_drive_auth.dart';
import 'google_sign_in_silent.dart';

class GoogleDriveService {
  GoogleDriveService(GoogleSignIn googleSignIn)
      : _googleSignIn = googleSignIn,
        _api = null;

  @visibleForTesting
  GoogleDriveService.withApi(drive.DriveApi api)
      : _googleSignIn = null,
        _api = api;

  final GoogleSignIn? _googleSignIn;
  drive.DriveApi? _api;

  static const driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// Nombre exacto de la carpeta raíz de backup en Google Drive.
  static const String backupFolderName = 'LifeTime_App';

  Future<drive.DriveApi> _getApi() async {
    final existing = _api;
    if (existing != null) return existing;
    final client = await _getAuthenticatedClient();
    final api = drive.DriveApi(client);
    _api = api;
    return api;
  }

  /// Cuenta Google actual + token con scope Drive para [drive.DriveApi].
  Future<http.Client> _getAuthenticatedClient() async {
    final signIn = _googleSignIn;
    if (signIn == null) {
      throw StateError('GoogleDriveService sin GoogleSignIn (modo test con withApi)');
    }

    final account = await googleSignInSilently(signIn);
    if (account == null) {
      throw const GoogleDriveAuthException(
        401,
        'No hay sesión Google activa (signInSilently)',
      );
    }

    final authorization = await account.authorizationClient.authorizeScopes(
      driveScopes,
    );
    return GoogleAuthHttpClient(<String, String>{
      'Authorization': 'Bearer ${authorization.accessToken}',
    });
  }

  Future<T> _withApi<T>(Future<T> Function(drive.DriveApi api) action) async {
    try {
      return await action(await _getApi());
    } catch (e) {
      rethrowIfGoogleDriveAuthError(e);
    }
  }

  /// Busca en la raíz del Drive del usuario [backupFolderName] o la crea.
  Future<String> getOrCreateBackupFolder() async {
    return getOrCreateFolder(backupFolderName, parentId: 'root');
  }

  Future<String> getOrCreateFolder(
    String folderName, {
    String? parentId,
  }) async {
    return _withApi((api) async {
      final q = <String>[
        "mimeType = 'application/vnd.google-apps.folder'",
        "name = '${folderName.replaceAll("'", "\\'")}'",
        "trashed = false",
        if (parentId != null) "'$parentId' in parents",
      ].join(' and ');

      final existing = await api.files.list(
        q: q,
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 10,
      );

      final files = existing.files ?? const <drive.File>[];
      if (files.isNotEmpty && files.first.id != null) {
        return files.first.id!;
      }

      final created = await api.files.create(
        drive.File(
          name: folderName,
          mimeType: 'application/vnd.google-apps.folder',
          parents: parentId == null ? null : [parentId],
        ),
        $fields: 'id',
      );

      final id = created.id;
      if (id == null) {
        throw StateError('Drive folder creation did not return id');
      }
      return id;
    });
  }

  Future<String> uploadFile(File file, String folderId) async {
    return _withApi((api) async {
      final name = p.basename(file.path);
      final length = await file.length();

      final media = drive.Media(
        file.openRead(),
        length,
        contentType: _contentTypeFromPath(name),
      );

      final created = await api.files.create(
        drive.File(
          name: name,
          parents: [folderId],
        ),
        uploadMedia: media,
        $fields: 'id',
      );

      final id = created.id;
      if (id == null) {
        throw StateError('Drive upload did not return id');
      }
      return id;
    });
  }

  Future<void> downloadFile(String fileId, String localPath) async {
    return _withApi((api) async {
      final outFile = File(localPath);
      await outFile.parent.create(recursive: true);

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (media is! drive.Media) {
        throw StateError('Drive download did not return media stream');
      }

      final sink = outFile.openWrite();
      try {
        await media.stream.pipe(sink);
      } finally {
        await sink.flush();
        await sink.close();
      }
    });
  }

  /// Borra un archivo/carpeta en Drive. Un 404 se trata como éxito (ya no existe).
  Future<void> deleteById(String fileOrFolderId) async {
    return _withApi((api) async {
      try {
        await api.files.delete(fileOrFolderId);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) return;
        rethrowIfGoogleDriveAuthError(e);
      }
    });
  }

  static String _contentTypeFromPath(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext == '.png') return 'image/png';
    if (ext == '.gif') return 'image/gif';
    if (ext == '.webp') return 'image/webp';
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    if (ext == '.mp4') return 'video/mp4';
    if (ext == '.mov') return 'video/quicktime';
    return 'application/octet-stream';
  }
}

class GoogleAuthHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;

  GoogleAuthHttpClient(this._headers, [http.Client? inner])
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
