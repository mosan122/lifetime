import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'package:lifetime/features/milestones/domain/usecases/upload_media_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/create_milestone_cubit.dart';

class MockCreateMilestoneUseCase extends Mock implements CreateMilestoneUseCase {}

class MockUploadMediaUseCase extends Mock implements UploadMediaUseCase {}

class MockPremiumService extends Mock implements PremiumService {}

void main() {
  late MockCreateMilestoneUseCase mockCreateMilestone;
  late MockUploadMediaUseCase mockUploadMedia;
  late MockPremiumService mockPremium;

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
    categoryId: 1,
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
    mockPremium = MockPremiumService();
    when(() => mockPremium.isPremium).thenReturn(true);
  });

  CreateMilestoneCubit buildCubit() =>
      CreateMilestoneCubit(mockCreateMilestone, mockUploadMedia, mockPremium);

  Future<List<CreateMilestoneState>> collectEmissionsDuring(
    CreateMilestoneCubit cubit,
    Future<void> Function() run,
  ) async {
    final emissions = <CreateMilestoneState>[];
    final sub = cubit.stream.listen(emissions.add);
    await run();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return emissions;
  }

  test('initial state is CreateMilestoneInitial', () {
    final cubit = buildCubit();
    expect(cubit.state, const CreateMilestoneInitial());
    return cubit.close();
  });

  test('emits [Submitting, Success] when no media and createMilestone succeeds',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Celebré mi 30 cumpleaños.',
        eventDate: tDate,
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting(),
      CreateMilestoneSuccess(tMilestone),
    ]);
    verify(() => mockCreateMilestone(any())).called(1);
    verifyNever(() => mockUploadMedia(any()));
    await cubit.close();
  });

  test('emits [Submitting, Error] when createMilestone returns AuthFailure',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => const Left(AuthFailure()));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Authentication error'),
    ]);
    await cubit.close();
  });

  test(
      'emits [Submitting, Error] with code when createMilestone returns NetworkFailure',
      () async {
    when(() => mockCreateMilestone(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('timeout', '500')),
    );
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('timeout', code: '500'),
    ]);
    await cubit.close();
  });

  test('emits [Submitting, Error] when biographer service fails', () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => const Left(BiographerFailure()));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Biographer service error'),
    ]);
    await cubit.close();
  });

  test('forwards all optional params to use case', () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    await cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      locationName: 'Madrid',
      latitude: 40.4168,
      longitude: -3.7038,
      categoryId: 2,
      participants: ['Ana'],
      isPublic: true,
    );
    final captured = verify(() => mockCreateMilestone(captureAny())).captured;
    final params = captured.first as CreateMilestoneParams;
    expect(params.locationName, equals('Madrid'));
    expect(params.latitude, equals(40.4168));
    expect(params.categoryId, equals(2));
    expect(params.participants, equals(['Ana']));
    expect(params.isPublic, isTrue);
    await cubit.close();
  });

  test('skips upload when mediaFiles is empty (even with accessToken)',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    await cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      accessToken: 'some-token',
    );
    verifyNever(() => mockUploadMedia(any()));
    await cubit.close();
  });

  test('skips upload when accessToken is null (even with mediaFiles)',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    await cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      mediaFiles: [File('/tmp/photo.jpg')],
    );
    verifyNever(() => mockUploadMedia(any()));
    await cubit.close();
  });

  test(
      'skips Drive upload when not premium even with mediaFiles and accessToken',
      () async {
    when(() => mockPremium.isPremium).thenReturn(false);
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Foto.',
        eventDate: tDate,
        mediaFiles: [File('/tmp/photo.jpg')],
        accessToken: 'ya29.access-token',
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting(),
      CreateMilestoneSuccess(tMilestone),
    ]);
    verifyNever(() => mockUploadMedia(any()));
    final captured = verify(() => mockCreateMilestone(captureAny())).captured;
    final params = captured.first as CreateMilestoneParams;
    expect(params.driveFileId, isNull);
    await cubit.close();
  });

  test(
      'emits [Submitting(upload), Submitting(redact), Success] when both steps succeed',
      () async {
    when(() => mockUploadMedia(any()))
        .thenAnswer((_) async => const Right('drive-file-id-123'));
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Foto del cumpleaños.',
        eventDate: tDate,
        mediaFiles: [File('/tmp/photo.jpg')],
        accessToken: 'ya29.access-token',
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneSubmitting('Redactando historia...'),
      CreateMilestoneSuccess(tMilestone),
    ]);
    verify(() => mockUploadMedia(any())).called(1);
    final captured = verify(() => mockCreateMilestone(captureAny())).captured;
    final params = captured.first as CreateMilestoneParams;
    expect(params.driveFileId, equals('drive-file-id-123'));
    await cubit.close();
  });

  test(
      'emits [Submitting(upload), Error] and never calls createMilestone when upload fails',
      () async {
    when(() => mockUploadMedia(any())).thenAnswer(
      (_) async =>
          const Left(NetworkFailure('quota exceeded', 'storageQuotaExceeded')),
    );
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Foto.',
        eventDate: tDate,
        mediaFiles: [File('/tmp/photo.jpg')],
        accessToken: 'ya29.access-token',
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneError('quota exceeded', code: 'storageQuotaExceeded'),
    ]);
    verifyNever(() => mockCreateMilestone(any()));
    await cubit.close();
  });

  test(
      'emits [Submitting(upload), Submitting(redact), Error] when upload ok but create fails',
      () async {
    when(() => mockUploadMedia(any()))
        .thenAnswer((_) async => const Right('drive-file-id-123'));
    when(() => mockCreateMilestone(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('server error', '503')),
    );
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Foto.',
        eventDate: tDate,
        mediaFiles: [File('/tmp/photo.jpg')],
        accessToken: 'ya29.access-token',
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Subiendo imagen...'),
      const CreateMilestoneSubmitting('Redactando historia...'),
      const CreateMilestoneError('server error', code: '503'),
    ]);
    await cubit.close();
  });

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

    test(
        'sets non-null imageBase64 when mediaFiles has a real JPEG (Vision without Drive)',
        () async {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
      final cubit = buildCubit();
      final emissions = await collectEmissionsDuring(
        cubit,
        () => cubit.submit(
          userNote: 'Foto del cumpleaños.',
          eventDate: tDate,
          mediaFiles: [tImageFile],
        ),
      );
      expect(emissions, [
        const CreateMilestoneSubmitting(),
        CreateMilestoneSuccess(tMilestone),
      ]);
      verifyNever(() => mockUploadMedia(any()));
      final captured = verify(() => mockCreateMilestone(captureAny())).captured;
      final params = captured.first as CreateMilestoneParams;
      expect(params.imageBase64, isNotNull);
      expect(params.driveFileId, isNull);
      await cubit.close();
    });

    test(
        'sets both driveFileId and imageBase64 when premium, mediaFiles and accessToken',
        () async {
      when(() => mockUploadMedia(any()))
          .thenAnswer((_) async => const Right('drive-file-id-456'));
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
      final cubit = buildCubit();
      final emissions = await collectEmissionsDuring(
        cubit,
        () => cubit.submit(
          userNote: 'Foto del cumpleaños.',
          eventDate: tDate,
          mediaFiles: [tImageFile],
          accessToken: 'ya29.token',
        ),
      );
      expect(emissions, [
        const CreateMilestoneSubmitting('Subiendo imagen...'),
        const CreateMilestoneSubmitting('Redactando historia...'),
        CreateMilestoneSuccess(tMilestone),
      ]);
      verify(() => mockUploadMedia(any())).called(1);
      final captured = verify(() => mockCreateMilestone(captureAny())).captured;
      final params = captured.first as CreateMilestoneParams;
      expect(params.driveFileId, equals('drive-file-id-456'));
      expect(params.imageBase64, isNotNull);
      await cubit.close();
    });
  });
}
