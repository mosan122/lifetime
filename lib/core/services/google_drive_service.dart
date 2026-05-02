import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class GoogleDriveService {
  final drive.DriveApi _api;

  GoogleDriveService(this._api);

  Future<String> getOrCreateFolder(
    String folderName, {
    String? parentId,
  }) async {
    final q = <String>[
      "mimeType = 'application/vnd.google-apps.folder'",
      "name = '${folderName.replaceAll("'", "\\'")}'",
      "trashed = false",
      if (parentId != null) "'$parentId' in parents",
    ].join(' and ');

    final existing = await _api.files.list(
      q: q,
      $fields: 'files(id,name)',
      spaces: 'drive',
      pageSize: 10,
    );

    final files = existing.files ?? const <drive.File>[];
    if (files.isNotEmpty && files.first.id != null) {
      return files.first.id!;
    }

    final created = await _api.files.create(
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
  }

  Future<String> uploadFile(File file, String folderId) async {
    final name = p.basename(file.path);
    final length = await file.length();

    final media = drive.Media(
      file.openRead(),
      length,
      contentType: _contentTypeFromPath(name),
    );

    final created = await _api.files.create(
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
  }

  Future<void> downloadFile(String fileId, String localPath) async {
    final outFile = File(localPath);
    await outFile.parent.create(recursive: true);

    final media = await _api.files.get(
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
  }

  Future<void> deleteById(String fileOrFolderId) async {
    await _api.files.delete(fileOrFolderId);
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

