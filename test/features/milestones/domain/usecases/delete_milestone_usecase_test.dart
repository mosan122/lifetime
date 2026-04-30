import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/delete_milestone_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

void main() {
  late MockMilestoneRepository mockRepository;
  late DeleteMilestoneUseCase useCase;

  setUp(() {
    mockRepository = MockMilestoneRepository();
    useCase = DeleteMilestoneUseCase(mockRepository);
  });

  test('calls repository.deleteMilestone with the correct id', () async {
    when(() => mockRepository.deleteMilestone(
          any(),
          accessToken: any(named: 'accessToken'),
        ))
        .thenAnswer((_) async => const Right(null));

    await useCase(const DeleteMilestoneParams('ms-1'));

    verify(() => mockRepository.deleteMilestone(
          'ms-1',
          accessToken: any(named: 'accessToken'),
        )).called(1);
  });

  test('forwards accessToken to repository.deleteMilestone', () async {
    when(() => mockRepository.deleteMilestone(
          any(),
          accessToken: any(named: 'accessToken'),
        ))
        .thenAnswer((_) async => const Right(null));

    const token = 'token-abc';
    await useCase(const DeleteMilestoneParams('ms-1', accessToken: token));

    verify(() => mockRepository.deleteMilestone(
          'ms-1',
          accessToken: token,
        )).called(1);
  });

  test('returns Right(null) when repository succeeds', () async {
    when(() => mockRepository.deleteMilestone(
          any(),
          accessToken: any(named: 'accessToken'),
        ))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(const DeleteMilestoneParams('ms-1'));

    expect(result.isRight(), isTrue);
  });

  test('returns Left(AuthFailure) when repository returns auth error', () async {
    when(() => mockRepository.deleteMilestone(
          any(),
          accessToken: any(named: 'accessToken'),
        ))
        .thenAnswer((_) async => const Left(AuthFailure()));

    final result = await useCase(const DeleteMilestoneParams('ms-1'));

    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(DatabaseFailure) when repository returns database error', () async {
    when(() => mockRepository.deleteMilestone(
          any(),
          accessToken: any(named: 'accessToken'),
        ))
        .thenAnswer((_) async => const Left(DatabaseFailure('not found', code: 'PGRST116')));

    final result = await useCase(const DeleteMilestoneParams('ms-999'));

    result.fold(
      (f) {
        expect(f, isA<DatabaseFailure>());
        expect(f.code, equals('PGRST116'));
      },
      (_) => fail('Expected Left'),
    );
  });

  test('DeleteMilestoneParams equality holds for same id', () {
    const p1 = DeleteMilestoneParams('ms-1');
    const p2 = DeleteMilestoneParams('ms-1');
    expect(p1, equals(p2));
  });

  test('DeleteMilestoneParams differs for different ids', () {
    const p1 = DeleteMilestoneParams('ms-1');
    const p2 = DeleteMilestoneParams('ms-2');
    expect(p1, isNot(equals(p2)));
  });
}
