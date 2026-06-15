import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/create_milestone_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

void main() {
  late MockMilestoneRepository mockRepository;
  late CreateMilestoneUseCase useCase;

  final tDate = DateTime(2026, 4, 26);
  final tParams = CreateMilestoneParams(
    userNote: 'Celebré mi 30 cumpleaños.',
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    category: 'familia',
    participants: const ['Ana', 'Luis'],
    isPublic: false,
  );

  final tMilestone = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const ['Ana', 'Luis'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    category: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  setUp(() {
    mockRepository = MockMilestoneRepository();
    useCase = CreateMilestoneUseCase(mockRepository);
    registerFallbackValue(tDate);
  });

  // Shared stub helper — must include imageBase64 matcher.
  void stubSuccess() {
    when(() => mockRepository.createMilestone(
          userNote: any(named: 'userNote'),
          eventDate: any(named: 'eventDate'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          category: any(named: 'category'),
          participants: any(named: 'participants'),
          isPublic: any(named: 'isPublic'),
          driveFileId: any(named: 'driveFileId'),
          imageBase64: any(named: 'imageBase64'),
          localMediaPaths: any(named: 'localMediaPaths'),
          localMediaTypes: any(named: 'localMediaTypes'),
        )).thenAnswer((_) async => Right(tMilestone));
  }

  test('forwards params to repository and returns Right(Milestone) on success', () async {
    stubSuccess();

    final result = await useCase(tParams);

    expect(result, Right(tMilestone));
    verify(() => mockRepository.createMilestone(
          userNote: tParams.userNote,
          eventDate: tParams.eventDate,
          locationName: tParams.locationName,
          latitude: tParams.latitude,
          longitude: tParams.longitude,
          category: tParams.category,
          participants: tParams.participants,
          isPublic: tParams.isPublic,
          driveFileId: tParams.driveFileId,
          imageBase64: tParams.imageBase64,
          localMediaPaths: tParams.localMediaPaths,
          localMediaTypes: tParams.localMediaTypes,
        )).called(1);
  });

  test('forwards imageBase64 to repository when provided', () async {
    const tBase64 = 'SGVsbG8gV29ybGQ=';
    final paramsWithImage = CreateMilestoneParams(
      userNote: 'Foto del cumpleaños.',
      eventDate: tDate,
      imageBase64: tBase64,
    );
    stubSuccess();

    await useCase(paramsWithImage);

    verify(() => mockRepository.createMilestone(
          userNote: paramsWithImage.userNote,
          eventDate: paramsWithImage.eventDate,
          locationName: paramsWithImage.locationName,
          latitude: paramsWithImage.latitude,
          longitude: paramsWithImage.longitude,
          category: paramsWithImage.category,
          participants: paramsWithImage.participants,
          isPublic: paramsWithImage.isPublic,
          driveFileId: paramsWithImage.driveFileId,
          imageBase64: tBase64,
          localMediaPaths: paramsWithImage.localMediaPaths,
          localMediaTypes: paramsWithImage.localMediaTypes,
        )).called(1);
  });

  test('forwards localMediaPaths to repository when provided', () async {
    const tLocalMediaPath = '/tmp/cache_photo.jpg';
    final paramsWithLocal = CreateMilestoneParams(
      userNote: 'Foto del cumpleaños.',
      eventDate: tDate,
      localMediaPaths: const [tLocalMediaPath],
    );
    stubSuccess();

    await useCase(paramsWithLocal);

    verify(() => mockRepository.createMilestone(
          userNote: paramsWithLocal.userNote,
          eventDate: paramsWithLocal.eventDate,
          locationName: paramsWithLocal.locationName,
          latitude: paramsWithLocal.latitude,
          longitude: paramsWithLocal.longitude,
          category: paramsWithLocal.category,
          participants: paramsWithLocal.participants,
          isPublic: paramsWithLocal.isPublic,
          driveFileId: paramsWithLocal.driveFileId,
          imageBase64: paramsWithLocal.imageBase64,
          localMediaPaths: paramsWithLocal.localMediaPaths,
          localMediaTypes: paramsWithLocal.localMediaTypes,
        )).called(1);
  });

  test('returns Left(AuthFailure) when repository returns auth error', () async {
    when(() => mockRepository.createMilestone(
          userNote: any(named: 'userNote'),
          eventDate: any(named: 'eventDate'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          category: any(named: 'category'),
          participants: any(named: 'participants'),
          isPublic: any(named: 'isPublic'),
          driveFileId: any(named: 'driveFileId'),
          imageBase64: any(named: 'imageBase64'),
          localMediaPaths: any(named: 'localMediaPaths'),
          localMediaTypes: any(named: 'localMediaTypes'),
        )).thenAnswer((_) async => const Left(AuthFailure()));

    final result = await useCase(tParams);

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) when repository returns network error', () async {
    when(() => mockRepository.createMilestone(
          userNote: any(named: 'userNote'),
          eventDate: any(named: 'eventDate'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          category: any(named: 'category'),
          participants: any(named: 'participants'),
          isPublic: any(named: 'isPublic'),
          driveFileId: any(named: 'driveFileId'),
          imageBase64: any(named: 'imageBase64'),
          localMediaPaths: any(named: 'localMediaPaths'),
          localMediaTypes: any(named: 'localMediaTypes'),
        )).thenAnswer(
      (_) async => const Left(NetworkFailure('timeout', '500')),
    );

    final result = await useCase(tParams);

    result.fold(
      (f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, equals('500'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('CreateMilestoneParams equality holds for same values', () {
    final p1 = CreateMilestoneParams(
      userNote: 'note',
      eventDate: DateTime(2026, 1, 1),
    );
    final p2 = CreateMilestoneParams(
      userNote: 'note',
      eventDate: DateTime(2026, 1, 1),
    );
    expect(p1, equals(p2));
  });

  test('CreateMilestoneParams with imageBase64 differs from without', () {
    final withImage = CreateMilestoneParams(
      userNote: 'note',
      eventDate: DateTime(2026, 1, 1),
      imageBase64: 'abc123',
    );
    final withoutImage = CreateMilestoneParams(
      userNote: 'note',
      eventDate: DateTime(2026, 1, 1),
    );
    expect(withImage, isNot(equals(withoutImage)));
  });
}
