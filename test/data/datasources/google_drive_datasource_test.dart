import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lifetime/data/datasources/google_drive_datasource.dart';

// Fake HTTP client that returns pre-queued responses in order.
class _FakeHttpClient extends http.BaseClient {
  final List<_FakeResponse> _queue;
  int _index = 0;

  _FakeHttpClient(this._queue);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = _queue[_index++];
    if (r.error != null) throw r.error!;
    return http.StreamedResponse(
      Stream.value(utf8.encode(r.body)),
      r.statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  @override
  void close() {}
}

class _FakeResponse {
  final String body;
  final int statusCode;
  final Object? error;

  const _FakeResponse({this.body = '', this.statusCode = 200, this.error});
}

// Canonical JSON payloads
const _folderExistsPayload = '{"files":[{"id":"folder-abc"}]}';
const _folderEmptyPayload = '{"files":[]}';
const _folderCreatedPayload = '{"id":"new-folder-def"}';
const _uploadedPayload = '{"id":"drive-xyz"}';
const _quotaErrorPayload =
    '{"error":{"code":403,"message":"Storage quota exceeded.",'
    '"errors":[{"reason":"storageQuotaExceeded","domain":"usageLimits",'
    '"message":"quota exceeded"}]}}';

void main() {
  late Directory tmpDir;
  late File tFile;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('drive_test_');
    tFile = File('${tmpDir.path}/photo.jpg');
    await tFile.writeAsBytes([0xFF, 0xD8, 0xFF]); // minimal JPEG header
  });

  tearDownAll(() async {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {} // Windows may lock the file briefly; ignore on cleanup
  });

  GoogleDriveDataSourceImpl buildSut(List<_FakeResponse> responses) =>
      GoogleDriveDataSourceImpl(_FakeHttpClient(responses));

  group('uploadMedia', () {
    test('returns Drive file ID when folder already exists', () async {
      final sut = buildSut([
        const _FakeResponse(body: _folderExistsPayload), // files.list
        const _FakeResponse(body: _uploadedPayload),     // files.create (upload)
      ]);

      final result = await sut.uploadMedia(
        file: tFile,
        accessToken: 'token-123',
      );

      expect(result, equals('drive-xyz'));
    });

    test('creates LifeTime_App folder when not found, then uploads', () async {
      final sut = buildSut([
        const _FakeResponse(body: _folderEmptyPayload),  // files.list → empty
        const _FakeResponse(body: _folderCreatedPayload), // files.create (folder)
        const _FakeResponse(body: _uploadedPayload),      // files.create (upload)
      ]);

      final result = await sut.uploadMedia(
        file: tFile,
        accessToken: 'token-123',
      );

      expect(result, equals('drive-xyz'));
    });

    test('throws DriveQuotaExceededException on 403 storageQuotaExceeded',
        () async {
      final sut = buildSut([
        const _FakeResponse(body: _folderExistsPayload),
        const _FakeResponse(body: _quotaErrorPayload, statusCode: 403),
      ]);

      await expectLater(
        () => sut.uploadMedia(file: tFile, accessToken: 'token-123'),
        throwsA(isA<DriveQuotaExceededException>()),
      );
    });

    test('throws DriveUploadTimeoutException on TimeoutException', () async {
      final sut = buildSut([
        const _FakeResponse(body: _folderExistsPayload),
        _FakeResponse(error: TimeoutException('mock timeout')),
      ]);

      await expectLater(
        () => sut.uploadMedia(file: tFile, accessToken: 'token-123'),
        throwsA(isA<DriveUploadTimeoutException>()),
      );
    });

    test('throws DriveUploadTimeoutException when folder search times out',
        () async {
      final sut = buildSut([
        _FakeResponse(error: TimeoutException('list timeout')),
      ]);

      await expectLater(
        () => sut.uploadMedia(file: tFile, accessToken: 'token-123'),
        throwsA(isA<DriveUploadTimeoutException>()),
      );
    });

    test('wraps unknown errors in DriveException', () async {
      final sut = buildSut([
        _FakeResponse(error: Exception('unexpected error')),
      ]);

      await expectLater(
        () => sut.uploadMedia(file: tFile, accessToken: 'token-123'),
        throwsA(isA<DriveException>()),
      );
    });
  });
}
