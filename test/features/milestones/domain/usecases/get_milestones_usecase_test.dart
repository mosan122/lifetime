import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/get_milestones_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

void main() {
  late MockMilestoneRepository mockRepository;
  late GetMilestonesUseCase useCase;

  final tMilestone = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const ['Ana'],
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
    useCase = GetMilestonesUseCase(mockRepository);
  });

  test('returns Right(List<Milestone>) on success', () async {
    when(() => mockRepository.getMilestones())
        .thenAnswer((_) async => Right([tMilestone]));

    final result = await useCase(const NoParams());

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected Right'),
      (list) => expect(list, [tMilestone]),
    );
    verify(() => mockRepository.getMilestones()).called(1);
  });

  test('returns Right with empty list when no milestones exist', () async {
    when(() => mockRepository.getMilestones())
        .thenAnswer((_) async => const Right([]));

    final result = await useCase(const NoParams());

    result.fold(
      (_) => fail('Expected Right'),
      (list) => expect(list, isEmpty),
    );
  });

  test('returns Left(DatabaseFailure) with code when repository fails', () async {
    when(() => mockRepository.getMilestones()).thenAnswer(
      (_) async => const Left(DatabaseFailure('connection error', code: '08000')),
    );

    final result = await useCase(const NoParams());

    result.fold(
      (f) {
        expect(f, isA<DatabaseFailure>());
        expect(f.code, equals('08000'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(AuthFailure) when user is not authenticated', () async {
    when(() => mockRepository.getMilestones())
        .thenAnswer((_) async => const Left(AuthFailure()));

    final result = await useCase(const NoParams());

    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('Expected Left'),
    );
  });
}
