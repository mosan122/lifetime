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

  test('forwards params to repository and returns Right(Milestone) on success', () async {
    when(() => mockRepository.createMilestone(
          userNote: any(named: 'userNote'),
          eventDate: any(named: 'eventDate'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          category: any(named: 'category'),
          participants: any(named: 'participants'),
          isPublic: any(named: 'isPublic'),
        )).thenAnswer((_) async => Right(tMilestone));

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
}
