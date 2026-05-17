import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'google_drive_auth.dart';
import 'google_drive_scope_auth.dart';
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

    final authorization = await driveAuthorizationSilently(account);
    if (authorization == null) {
      throw const GoogleDriveAuthException(
        401,
        'Drive no autorizado (conéctalo desde Ajustes o el panel Premium)',
      );
    }
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

  /// Nombres de carpeta raíz conocidos (actual e histórico).
  static const backupFolderNames = ['LifeTime_App', 'LifeTime'];

  /// Busca en la raíz del Drive del usuario [backupFolderName] o la crea.
  Future<String> getOrCreateBackupFolder() async {
    return getOrCreateFolder(backupFolderName, parentId: 'root');
  }

  /// Carpeta raíz existente sin crearla (`LifeTime_App` o `LifeTime`).
  Future<String?> findExistingBackupFolder() async {
    for (final name in backupFolderNames) {
      final id = await findFolderByName(name, parentId: 'root');
      if (id != null) return id;
    }
    return null;
  }

  /// Busca una subcarpeta por nombre; no crea si no existe.
  Future<String?> findFolderByName(
    String folderName, {
    String parentId = 'root',
  }) async {
    return _withApi((api) async {
      final q = <String>[
        "mimeType = 'application/vnd.google-apps.folder'",
        "name = '${folderName.replaceAll("'", "\\'")}'",
        "trashed = false",
        "'$parentId' in parents",
      ].join(' and ');

      final existing = await api.files.list(
        q: q,
        $fields: 'files(id)',
        spaces: 'drive',
        pageSize: 1,
      );
      final files = existing.files ?? const <drive.File>[];
      if (files.isEmpty || files.first.id == null) return null;
      return files.first.id;
    });
  }

  /// Lista hijos directos de una carpeta (paginado).
  Future<DriveFolderListing> listFolderChildren(String parentId) async {
    return _withApi((api) async {
      final folders = <DriveListedFolder>[];
      final files = <DriveListedFile>[];
      String? pageToken;

      do {
        final page = await api.files.list(
          q: "'$parentId' in parents and trashed = false",
          $fields: 'nextPageToken, files(id, name, mimeType)',
          spaces: 'drive',
          pageSize: 200,
          pageToken: pageToken,
        );

        for (final entry in page.files ?? const <drive.File>[]) {
          final id = entry.id;
          final name = entry.name;
          if (id == null || name == null) continue;
          final mime = entry.mimeType ?? '';
          if (mime == 'application/vnd.google-apps.folder') {
            folders.add(DriveListedFolder(id: id, name: name));
          } else if (!mime.startsWith('application/vnd.google-apps.')) {
            files.add(
              DriveListedFile(
                id: id,
                name: name,
                mimeType: mime,
              ),
            );
          }
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null);

      return DriveFolderListing(folders: folders, files: files);
    });
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

  /// Si ya existe un archivo con el mismo nombre en la carpeta, devuelve su id
  /// (evita duplicados por re-sincronización).
  Future<String?> findFileIdByNameInFolder(
    String folderId,
    String fileName,
  ) async {
    return _withApi((api) async {
      final escaped = fileName.replaceAll("'", r"\'");
      final q =
          "name = '$escaped' and '$folderId' in parents and trashed = false";
      final page = await api.files.list(
        q: q,
        $fields: 'files(id)',
        spaces: 'drive',
        pageSize: 1,
      );
      final files = page.files;
      if (files == null || files.isEmpty) return null;
      final id = files.first.id;
      return (id == null || id.isEmpty) ? null : id;
    });
  }

  Future<String> uploadFile(File file, String folderId) async {
    final name = p.basename(file.path);
    final existing = await findFileIdByNameInFolder(folderId, name);
    if (existing != null) return existing;

    return _withApi((api) async {
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

  /// Cuota de almacenamiento de la cuenta Google vinculada (`about.storageQuota`).
  Future<GoogleDriveStorageQuota> fetchStorageQuota() async {
    return _withApi((api) async {
      final about = await api.about.get($fields: 'storageQuota');
      final q = about.storageQuota;
      return GoogleDriveStorageQuota(
        usageBytes: _parseQuotaBytes(q?.usage) ?? 0,
        limitBytes: _parseQuotaBytes(q?.limit),
      );
    });
  }

  static int? _parseQuotaBytes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
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

class DriveListedFolder {
  const DriveListedFolder({required this.id, required this.name});

  final String id;
  final String name;
}

class DriveListedFile {
  const DriveListedFile({
    required this.id,
    required this.name,
    required this.mimeType,
  });

  final String id;
  final String name;
  final String mimeType;
}

class DriveFolderListing {
  const DriveFolderListing({
    required this.folders,
    required this.files,
  });

  final List<DriveListedFolder> folders;
  final List<DriveListedFile> files;
}

class GoogleDriveStorageQuota {
  const GoogleDriveStorageQuota({
    required this.usageBytes,
    this.limitBytes,
  });

  final int usageBytes;
  final int? limitBytes;

  bool get hasLimit => limitBytes != null && limitBytes! > 0;
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
