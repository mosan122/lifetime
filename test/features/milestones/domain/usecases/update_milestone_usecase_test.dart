import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/update_milestone_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

void main() {
  late MockMilestoneRepository mockRepository;
  late UpdateMilestoneUseCase useCase;

  final tDate = DateTime(2026, 4, 26);
  final tMilestone = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Relato actualizado.',
    participants: const [],
    media: const [],
    eventDate: tDate,
    locationName: 'Sevilla',
    latitude: 37.3886,
    longitude: -5.9823,
    category: 'familia',
    isPublic: false,
    createdAt: tDate,
  );

  const tParams = UpdateMilestoneParams(
    id: 'ms-1',
    title: 'Mi 30 cumpleaños',
    description: 'Relato actualizado.',
    locationName: 'Sevilla',
    latitude: 37.3886,
    longitude: -5.9823,
  );

  void stubSuccess() {
    when(() => mockRepository.updateMilestone(
          id: any(named: 'id'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => Right(tMilestone));
  }

  setUp(() {
    mockRepository = MockMilestoneRepository();
    useCase = UpdateMilestoneUseCase(mockRepository);
  });

  test('forwards all params to repository.updateMilestone', () async {
    stubSuccess();

    await useCase(tParams);

    verify(() => mockRepository.updateMilestone(
          id: 'ms-1',
          title: 'Mi 30 cumpleaños',
          description: 'Relato actualizado.',
          locationName: 'Sevilla',
          latitude: 37.3886,
          longitude: -5.9823,
        )).called(1);
  });

  test('returns Right(Milestone) when repository succeeds', () async {
    stubSuccess();

    final result = await useCase(tParams);

    expect(result, Right(tMilestone));
  });

  test('forwards null optional fields when not provided', () async {
    stubSuccess();
    const paramsMinimal = UpdateMilestoneParams(
      id: 'ms-2',
      title: 'Título',
      description: 'Sólo descripción.',
    );

    await useCase(paramsMinimal);

    verify(() => mockRepository.updateMilestone(
          id: 'ms-2',
          title: 'Título',
          description: 'Sólo descripción.',
          locationName: null,
          latitude: null,
          longitude: null,
        )).called(1);
  });

  test('returns Left(AuthFailure) when repository returns auth error', () async {
    when(() => mockRepository.updateMilestone(
          id: any(named: 'id'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => const Left(AuthFailure()));

    final result = await useCase(tParams);

    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(DatabaseFailure) when repository returns database error', () async {
    when(() => mockRepository.updateMilestone(
          id: any(named: 'id'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer(
      (_) async => const Left(DatabaseFailure('not found', code: 'PGRST116')),
    );

    final result = await useCase(tParams);

    result.fold(
      (f) {
        expect(f, isA<DatabaseFailure>());
        expect(f.code, equals('PGRST116'));
      },
      (_) => fail('Expected Left'),
    );
  });

  group('UpdateMilestoneParams', () {
    test('equality holds for same values', () {
      const p1 = UpdateMilestoneParams(
        id: 'ms-1',
        title: 'Relato',
        description: 'Relato.',
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
      );
      const p2 = UpdateMilestoneParams(
        id: 'ms-1',
        title: 'Relato',
        description: 'Relato.',
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
      );
      expect(p1, equals(p2));
    });

    test('differs when description changes', () {
      const p1 = UpdateMilestoneParams(id: 'ms-1', title: 'T', description: 'A');
      const p2 = UpdateMilestoneParams(id: 'ms-1', title: 'T', description: 'B');
      expect(p1, isNot(equals(p2)));
    });

    test('differs when id changes', () {
      const p1 = UpdateMilestoneParams(id: 'ms-1', title: 'T', description: 'Same');
      const p2 = UpdateMilestoneParams(id: 'ms-2', title: 'T', description: 'Same');
      expect(p1, isNot(equals(p2)));
    });
  });
}
