import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/domain/repositories/drive_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/upload_media_usecase.dart';

class MockDriveRepository extends Mock implements DriveRepository {}

void main() {
  late MockDriveRepository mockRepo;
  late UploadMediaUseCase sut;

  final tFile = File('/tmp/photo.jpg');

  setUpAll(() {
    registerFallbackValue(tFile);
  });

  setUp(() {
    mockRepo = MockDriveRepository();
    sut = UploadMediaUseCase(mockRepo);
  });

  test('returns Right(driveId) on success', () async {
    when(() => mockRepo.uploadMedia(
          file: any(named: 'file'),
          accessToken: any(named: 'accessToken'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async => const Right('drive-xyz'));

    final result = await sut(UploadMediaParams(
      file: tFile,
      accessToken: 'token-abc',
    ));

    expect(result, equals(const Right<Failure, String>('drive-xyz')));
  });

  test('returns Left(NetworkFailure) when repository fails', () async {
    when(() => mockRepo.uploadMedia(
          file: any(named: 'file'),
          accessToken: any(named: 'accessToken'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async =>
        const Left(NetworkFailure('quota exceeded', 'storageQuotaExceeded')));

    final result = await sut(UploadMediaParams(
      file: tFile,
      accessToken: 'token-abc',
    ));

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('storageQuotaExceeded'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('forwards all params to repository', () async {
    when(() => mockRepo.uploadMedia(
          file: any(named: 'file'),
          accessToken: any(named: 'accessToken'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async => const Right('drive-xyz'));

    await sut(UploadMediaParams(
      file: tFile,
      accessToken: 'my-token',
      mimeType: 'image/jpeg',
    ));

    final captured = verify(() => mockRepo.uploadMedia(
          file: captureAny(named: 'file'),
          accessToken: captureAny(named: 'accessToken'),
          mimeType: captureAny(named: 'mimeType'),
        )).captured;

    expect(captured[0], equals(tFile));
    expect(captured[1], equals('my-token'));
    expect(captured[2], equals('image/jpeg'));
  });
}
