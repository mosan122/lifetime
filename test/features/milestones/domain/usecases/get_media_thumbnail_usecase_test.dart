import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/domain/repositories/drive_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/get_media_thumbnail_usecase.dart';

class MockDriveRepository extends Mock implements DriveRepository {}

void main() {
  late MockDriveRepository mockRepository;
  late GetMediaThumbnailUseCase useCase;

  const tFileId = 'drive-file-id-abc';
  const tAccessToken = 'ya29.access-token';
  const tThumbnailUrl = 'https://lh3.googleusercontent.com/thumbnail-url';

  final tParams = const GetMediaThumbnailParams(
    fileId: tFileId,
    accessToken: tAccessToken,
  );

  setUp(() {
    mockRepository = MockDriveRepository();
    useCase = GetMediaThumbnailUseCase(mockRepository);
  });

  test('returns Right(thumbnailUrl) on success', () async {
    when(() => mockRepository.getThumbnailLink(
          fileId: any(named: 'fileId'),
          accessToken: any(named: 'accessToken'),
        )).thenAnswer((_) async => const Right(tThumbnailUrl));

    final result = await useCase(tParams);

    expect(result, const Right<Failure, String>(tThumbnailUrl));
    verify(() => mockRepository.getThumbnailLink(
          fileId: tFileId,
          accessToken: tAccessToken,
        )).called(1);
  });

  test('returns Left(NetworkFailure) when Drive reports no thumbnail', () async {
    when(() => mockRepository.getThumbnailLink(
          fileId: any(named: 'fileId'),
          accessToken: any(named: 'accessToken'),
        )).thenAnswer(
      (_) async => const Left(NetworkFailure('No thumbnail available', 'noThumbnail')),
    );

    final result = await useCase(tParams);

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('noThumbnail'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) when Drive quota exceeded', () async {
    when(() => mockRepository.getThumbnailLink(
          fileId: any(named: 'fileId'),
          accessToken: any(named: 'accessToken'),
        )).thenAnswer(
      (_) async =>
          const Left(NetworkFailure('Storage quota exceeded', 'storageQuotaExceeded')),
    );

    final result = await useCase(tParams);

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('storageQuotaExceeded'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) on timeout', () async {
    when(() => mockRepository.getThumbnailLink(
          fileId: any(named: 'fileId'),
          accessToken: any(named: 'accessToken'),
        )).thenAnswer(
      (_) async => const Left(NetworkFailure('Upload timed out', 'timeout')),
    );

    final result = await useCase(tParams);

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('timeout'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('GetMediaThumbnailParams equality holds for same values', () {
    const p1 = GetMediaThumbnailParams(fileId: 'f', accessToken: 'a');
    const p2 = GetMediaThumbnailParams(fileId: 'f', accessToken: 'a');
    expect(p1, equals(p2));
  });

  test('GetMediaThumbnailParams inequality when fileId differs', () {
    const p1 = GetMediaThumbnailParams(fileId: 'f1', accessToken: 'a');
    const p2 = GetMediaThumbnailParams(fileId: 'f2', accessToken: 'a');
    expect(p1, isNot(equals(p2)));
  });
}
