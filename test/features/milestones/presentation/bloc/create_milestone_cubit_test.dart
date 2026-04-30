import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'package:lifetime/features/milestones/domain/usecases/upload_media_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/create_milestone_cubit.dart';

class MockCreateMilestoneUseCase extends Mock implements CreateMilestoneUseCase {}

class MockUploadMediaUseCase extends Mock implements UploadMediaUseCase {}

void main() {
  late MockCreateMilestoneUseCase mockCreateMilestone;
  late MockUploadMediaUseCase mockUploadMedia;

  final tDate = DateTime(2026, 4, 26);
  final tMilestone = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const [],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: null,
    latitude: null,
    longitude: null,
    category: 'general',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  setUpAll(() {
    registerFallbackValue(
      CreateMilestoneParams(userNote: '', eventDate: DateTime(2026)),
    );
    registerFallbackValue(
      UploadMediaParams(file: File(''), accessToken: ''),
    );
  });

  setUp(() {
    mockCreateMilestone = MockCreateMilestoneUseCase();
    mockUploadMedia = MockUploadMediaUseCase();
  });

  CreateMilestoneCubit buildCubit() =>
      CreateMilestoneCubit(mockCreateMilestone, mockUploadMedia);

  test('initial state is CreateMilestoneInitial', () {
    final cubit = buildCubit();
    expect(cubit.state, const CreateMilestoneInitial());
    cubit.close();
  });

  // ── No media (upload step skipped) ───────────────────────────────────────

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Success] when no media and createMilestone succeeds',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Celebré mi 30 cumpleaños.',
      eventDate: tDate,
    ),
    expect: () => [
      const CreateMilestoneSubmitting(),
      CreateMilestoneSuccess(tMilestone),
    ],
    verify: (_) {
      verify(() => mockCreateMilestone(any())).called(1);
      verifyNever(() => mockUploadMedia(any()));
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] when createMilestone returns AuthFailure',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => const Left(AuthFailure()));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(userNote: 'Nota', eventDate: tDate),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Authentication error'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] with code when createMilestone returns NetworkFailure',
    setUp: () {
      when(() => mockCreateMilestone(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('timeout', '500')),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(userNote: 'Nota', eventDate: tDate),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('timeout', code: '500'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] when biographer service fails',
    setUp: () {
      when(() => mockCreateMilestone(any())).thenAnswer(
        (_) async => const Left(BiographerFailure()),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(userNote: 'Nota', eventDate: tDate),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Biographer service error'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'forwards all optional params to use case',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      locationName: 'Madrid',
      latitude: 40.4168,
      longitude: -3.7038,
      category: 'familia',
      participants: ['Ana'],
      isPublic: true,
    ),
    verify: (_) {
      final captured = verify(() => mockCreateMilestone(captureAny())).captured;
      final params = captured.first as CreateMilestoneParams;
      expect(params.locationName, equals('Madrid'));
      expect(params.latitude, equals(40.4168));
      expect(params.category, equals('familia'));
      expect(params.participants, equals(['Ana']));
      expect(params.isPublic, isTrue);
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'skips upload when mediaFile is null (even with accessToken)',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      accessToken: 'some-token',
    ),
    verify: (_) {
      verifyNever(() => mockUploadMedia(any()));
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'skips upload when accessToken is null (even with mediaFile)',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      mediaFile: File('/tmp/photo.jpg'),
    ),
    verify: (_) {
      verifyNever(() => mockUploadMedia(any()));
    },
  );

  // ── With media (upload step runs) ─────────────────────────────────────────

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting(upload), Submitting(redact), Success] when both steps succeed',
    setUp: () {
      when(() => mockUploadMedia(any()))
          .thenAnswer((_) async => const Right('drive-file-id-123'));
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Foto del cumpleaños.',
      eventDate: tDate,
      mediaFile: File('/tmp/photo.jpg'),
      accessToken: 'ya29.access-token',
    ),
    expect: () => [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneSubmitting('Redactando historia...'),
      CreateMilestoneSuccess(tMilestone),
    ],
    verify: (_) {
      verify(() => mockUploadMedia(any())).called(1);
      final captured = verify(() => mockCreateMilestone(captureAny())).captured;
      final params = captured.first as CreateMilestoneParams;
      expect(params.driveFileId, equals('drive-file-id-123'));
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting(upload), Error] and never calls createMilestone when upload fails',
    setUp: () {
      when(() => mockUploadMedia(any())).thenAnswer(
        (_) async =>
            const Left(NetworkFailure('quota exceeded', 'storageQuotaExceeded')),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Foto.',
      eventDate: tDate,
      mediaFile: File('/tmp/photo.jpg'),
      accessToken: 'ya29.access-token',
    ),
    expect: () => [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneError('quota exceeded', code: 'storageQuotaExceeded'),
    ],
    verify: (_) {
      verifyNever(() => mockCreateMilestone(any()));
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting(upload), Submitting(redact), Error] when upload ok but create fails',
    setUp: () {
      when(() => mockUploadMedia(any()))
          .thenAnswer((_) async => const Right('drive-file-id-123'));
      when(() => mockCreateMilestone(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('server error', '503')),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.submit(
      userNote: 'Foto.',
      eventDate: tDate,
      mediaFile: File('/tmp/photo.jpg'),
      accessToken: 'ya29.access-token',
    ),
    expect: () => [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneSubmitting('Redactando historia...'),
      const CreateMilestoneError('server error', code: '503'),
    ],
  );

  // ── Vision encoding with a real image file ────────────────────────────────

  group('with real image file', () {
    late File tImageFile;

    setUp(() async {
      final dir = Directory.systemTemp;
      tImageFile = File(
        '${dir.path}/test_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final image = img.Image(width: 2, height: 2);
      await tImageFile.writeAsBytes(img.encodeJpg(image));
    });

    tearDown(() async {
      if (await tImageFile.exists()) await tImageFile.delete();
    });

    blocTest<CreateMilestoneCubit, CreateMilestoneState>(
      'sets non-null imageBase64 when mediaFile is a real JPEG (Vision without Drive)',
      setUp: () {
        when(() => mockCreateMilestone(any()))
            .thenAnswer((_) async => Right(tMilestone));
      },
      build: buildCubit,
      act: (cubit) async => cubit.submit(
        userNote: 'Foto del cumpleaños.',
        eventDate: tDate,
        mediaFile: tImageFile, // real file, no accessToken → no Drive upload
      ),
      expect: () => [
        const CreateMilestoneSubmitting(),
        CreateMilestoneSuccess(tMilestone),
      ],
      verify: (_) {
        verifyNever(() => mockUploadMedia(any()));
        final captured = verify(() => mockCreateMilestone(captureAny())).captured;
        final params = captured.first as CreateMilestoneParams;
        expect(params.imageBase64, isNotNull);
        expect(params.driveFileId, isNull);
      },
    );

    blocTest<CreateMilestoneCubit, CreateMilestoneState>(
      'sets both driveFileId and imageBase64 when mediaFile and accessToken provided',
      setUp: () {
        when(() => mockUploadMedia(any()))
            .thenAnswer((_) async => const Right('drive-file-id-456'));
        when(() => mockCreateMilestone(any()))
            .thenAnswer((_) async => Right(tMilestone));
      },
      build: buildCubit,
      act: (cubit) async => cubit.submit(
        userNote: 'Foto del cumpleaños.',
        eventDate: tDate,
        mediaFile: tImageFile,
        accessToken: 'ya29.token',
      ),
      expect: () => [
        const CreateMilestoneSubmitting('Subiendo imagen...'),
        const CreateMilestoneSubmitting('Redactando historia...'),
        CreateMilestoneSuccess(tMilestone),
      ],
      verify: (_) {
        verify(() => mockUploadMedia(any())).called(1);
        final captured = verify(() => mockCreateMilestone(captureAny())).captured;
        final params = captured.first as CreateMilestoneParams;
        expect(params.driveFileId, equals('drive-file-id-456'));
        expect(params.imageBase64, isNotNull);
      },
    );
  });
}
