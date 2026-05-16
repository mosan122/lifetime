import 'dart:async';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart' as http;

// ── Exceptions ────────────────────────────────────────────────────────────────

class DriveException implements Exception {
  final String message;
  final String? code;
  const DriveException(this.message, {this.code});
  @override
  String toString() =>
      'DriveException($message${code != null ? ', code: $code' : ''})';
}

class DriveQuotaExceededException extends DriveException {
  const DriveQuotaExceededException()
      : super('Storage quota exceeded', code: 'storageQuotaExceeded');
}

class DriveUploadTimeoutException extends DriveException {
  const DriveUploadTimeoutException()
      : super('Upload timed out', code: 'timeout');
}

// ── Interface ─────────────────────────────────────────────────────────────────

abstract class GoogleDriveDataSource {
  Future<String> uploadMedia({
    required File file,
    required String accessToken,
    String mimeType = 'application/octet-stream',
  });

  /// Returns the Drive-provided thumbnail URL for [fileId].
  /// The returned URL must be fetched with a credentialed request (Bearer token).
  Future<String> getThumbnailLink({
    required String fileId,
    required String accessToken,
  });

  Future<void> deleteFile({
    required String fileId,
    required String accessToken,
  });
}

// ── Implementation ────────────────────────────────────────────────────────────

class GoogleDriveDataSourceImpl implements GoogleDriveDataSource {
  static const _folderName = 'LifeTime_App';
  static const _folderMime = 'application/vnd.google-apps.folder';

  final http.Client _httpClient;

  const GoogleDriveDataSourceImpl(this._httpClient);

  @override
  Future<String> uploadMedia({
    required File file,
    required String accessToken,
    String mimeType = 'application/octet-stream',
  }) async {
    final api = gd.DriveApi(_AuthenticatedClient(accessToken, _httpClient));
    try {
      final folderId = await _getOrCreateFolder(api);
      return await _uploadFile(api, file, folderId, mimeType);
    } on TimeoutException {
      throw const DriveUploadTimeoutException();
    } on gd.DetailedApiRequestError catch (e) {
      _mapApiError(e);
    } catch (e) {
      if (e is DriveException) rethrow;
      throw DriveException(e.toString());
    }
  }

  Future<String> _getOrCreateFolder(gd.DriveApi api) async {
    final list = await api.files
        .list(
          q: "name='$_folderName' and mimeType='$_folderMime' "
              "and trashed=false and 'root' in parents",
          spaces: 'drive',
          $fields: 'files(id)',
        )
        .timeout(const Duration(seconds: 30));

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = gd.File()
      ..name = _folderName
      ..mimeType = _folderMime
      ..parents = ['root'];

    final created = await api.files
        .create(folder, $fields: 'id')
        .timeout(const Duration(seconds: 30));

    if (created.id == null) {
      throw const DriveException('Folder creation returned no ID');
    }
    return created.id!;
  }

  Future<String> _uploadFile(
    gd.DriveApi api,
    File file,
    String folderId,
    String mimeType,
  ) async {
    final length = await file.length();
    final media = gd.Media(file.openRead(), length, contentType: mimeType);
    final meta = gd.File()
      ..name = file.uri.pathSegments.lastWhere((s) => s.isNotEmpty)
      ..parents = [folderId];

    final result = await api.files
        .create(meta, uploadMedia: media, $fields: 'id')
        .timeout(const Duration(minutes: 5));

    if (result.id == null) {
      throw const DriveException('Upload returned no file ID');
    }
    return result.id!;
  }

  @override
  Future<String> getThumbnailLink({
    required String fileId,
    required String accessToken,
  }) async {
    final api = gd.DriveApi(_AuthenticatedClient(accessToken, _httpClient));
    try {
      final file = await api.files
          .get(fileId, $fields: 'thumbnailLink')
          .timeout(const Duration(seconds: 15)) as gd.File;
      if (file.thumbnailLink == null) {
        throw const DriveException('No thumbnail available', code: 'noThumbnail');
      }
      return file.thumbnailLink!;
    } on TimeoutException {
      throw const DriveUploadTimeoutException();
    } on gd.DetailedApiRequestError catch (e) {
      _mapApiError(e);
    } catch (e) {
      if (e is DriveException) rethrow;
      throw DriveException(e.toString());
    }
  }

  @override
  Future<void> deleteFile({
    required String fileId,
    required String accessToken,
  }) async {
    final api = gd.DriveApi(_AuthenticatedClient(accessToken, _httpClient));
    try {
      await api.files.delete(fileId).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const DriveUploadTimeoutException();
    } on gd.DetailedApiRequestError catch (e) {
      _mapApiError(e);
    } catch (e) {
      if (e is DriveException) rethrow;
      throw DriveException(e.toString());
    }
  }

  Never _mapApiError(gd.DetailedApiRequestError e) {
    final reasons = e.errors.map((err) => err.reason ?? '').toList();
    if (e.status == 403 &&
        reasons.any((r) =>
            r == 'storageQuotaExceeded' || r == 'userRateLimitExceeded')) {
      throw const DriveQuotaExceededException();
    }
    throw DriveException(
      e.message ?? 'Drive API error',
      code: e.status?.toString(),
    );
  }
}

// ── Authenticated HTTP wrapper ─────────────────────────────────────────────────

class _AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner;

  _AuthenticatedClient(this._token, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {} // shared client — don't close it here
}
