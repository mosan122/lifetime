import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/datasources/google_drive_datasource.dart';
import 'package:lifetime/data/repositories/drive_repository_impl.dart';

class MockGoogleDriveDataSource extends Mock
    implements GoogleDriveDataSource {}

void main() {
  late MockGoogleDriveDataSource mockDatasource;
  late DriveRepositoryImpl sut;

  final tFile = File('/tmp/photo.jpg');

  setUpAll(() {
    registerFallbackValue(tFile);
  });

  setUp(() {
    mockDatasource = MockGoogleDriveDataSource();
    sut = DriveRepositoryImpl(mockDatasource);
  });

  void stubSuccess() {
    when(() => mockDatasource.uploadMedia(
          file: any(named: 'file'),
          accessToken: any(named: 'accessToken'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async => 'drive-xyz');
  }

  void stubThrow(Object error) {
    when(() => mockDatasource.uploadMedia(
          file: any(named: 'file'),
          accessToken: any(named: 'accessToken'),
          mimeType: any(named: 'mimeType'),
        )).thenThrow(error);
  }

  test('returns Right(driveId) on success', () async {
    stubSuccess();

    final result = await sut.uploadMedia(
      file: tFile,
      accessToken: 'token-abc',
    );

    expect(result, equals(const Right<Failure, String>('drive-xyz')));
  });

  test('returns Left(NetworkFailure) with quota code on DriveQuotaExceededException',
      () async {
    stubThrow(const DriveQuotaExceededException());

    final result = await sut.uploadMedia(
      file: tFile,
      accessToken: 'token-abc',
    );

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('storageQuotaExceeded'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) with timeout code on DriveUploadTimeoutException',
      () async {
    stubThrow(const DriveUploadTimeoutException());

    final result = await sut.uploadMedia(
      file: tFile,
      accessToken: 'token-abc',
    );

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('timeout'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) on generic DriveException', () async {
    stubThrow(const DriveException('some drive error', code: '500'));

    final result = await sut.uploadMedia(
      file: tFile,
      accessToken: 'token-abc',
    );

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.message, equals('some drive error'));
        expect(f.code, equals('500'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) on unexpected exception', () async {
    stubThrow(Exception('boom'));

    final result = await sut.uploadMedia(
      file: tFile,
      accessToken: 'token-abc',
    );

    expect(result.isLeft(), isTrue);
  });

  // ── getThumbnailLink ─────────────────────────────────────────────────────

  group('getThumbnailLink', () {
    void stubThumbnailSuccess() {
      when(() => mockDatasource.getThumbnailLink(
            fileId: any(named: 'fileId'),
            accessToken: any(named: 'accessToken'),
          )).thenAnswer((_) async => 'https://lh3.google.com/thumb');
    }

    void stubThumbnailThrow(Object error) {
      when(() => mockDatasource.getThumbnailLink(
            fileId: any(named: 'fileId'),
            accessToken: any(named: 'accessToken'),
          )).thenThrow(error);
    }

    test('returns Right(thumbnailUrl) on success', () async {
      stubThumbnailSuccess();

      final result = await sut.getThumbnailLink(
        fileId: 'file-abc',
        accessToken: 'token-abc',
      );

      expect(result,
          equals(const Right<Failure, String>('https://lh3.google.com/thumb')));
    });

    test('returns Left(NetworkFailure) on DriveException(noThumbnail)', () async {
      stubThumbnailThrow(
          const DriveException('No thumbnail available', code: 'noThumbnail'));

      final result = await sut.getThumbnailLink(
        fileId: 'file-abc',
        accessToken: 'token-abc',
      );

      result.fold(
        (f) {
          expect(f, isA<NetworkFailure>());
          expect(f.code, equals('noThumbnail'));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(NetworkFailure) on DriveUploadTimeoutException', () async {
      stubThumbnailThrow(const DriveUploadTimeoutException());

      final result = await sut.getThumbnailLink(
        fileId: 'file-abc',
        accessToken: 'token-abc',
      );

      result.fold(
        (f) {
          expect(f, isA<NetworkFailure>());
          expect(f.code, equals('timeout'));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(NetworkFailure) on unexpected exception', () async {
      stubThumbnailThrow(Exception('network error'));

      final result = await sut.getThumbnailLink(
        fileId: 'file-abc',
        accessToken: 'token-abc',
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
