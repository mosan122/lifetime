import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/features/milestones/domain/usecases/delete_milestone_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/delete_milestone_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockDeleteMilestoneUseCase extends Mock implements DeleteMilestoneUseCase {}

class FakeDeleteMilestoneParams extends Fake implements DeleteMilestoneParams {}

void main() {
  late MockDeleteMilestoneUseCase mockDeleteMilestoneUseCase;

  setUpAll(() {
    registerFallbackValue(FakeDeleteMilestoneParams());
  });

  setUp(() {
    mockDeleteMilestoneUseCase = MockDeleteMilestoneUseCase();
  });

  DeleteMilestoneCubit buildCubit() => DeleteMilestoneCubit(mockDeleteMilestoneUseCase);

  test('initial state is DeleteMilestoneIdle', () {
    final cubit = buildCubit();
    expect(cubit.state, const DeleteMilestoneIdle());
    cubit.close();
  });

  blocTest<DeleteMilestoneCubit, DeleteMilestoneState>(
    'emits [DeleteMilestoneDeleting, DeleteMilestoneSuccess] when usecase succeeds',
    setUp: () {
      when(() => mockDeleteMilestoneUseCase(any()))
          .thenAnswer((_) async => const Right(null));
    },
    build: buildCubit,
    act: (cubit) => cubit.delete('ms-1', accessToken: 'token-abc'),
    expect: () => const [
      DeleteMilestoneDeleting(),
      DeleteMilestoneSuccess(),
    ],
  );

  test('forwards id and accessToken to DeleteMilestoneUseCase', () async {
    when(() => mockDeleteMilestoneUseCase(any()))
        .thenAnswer((_) async => const Right(null));

    final cubit = buildCubit();
    await cubit.delete('ms-1', accessToken: 'token-abc');

    final captured =
        verify(() => mockDeleteMilestoneUseCase(captureAny())).captured.single
            as DeleteMilestoneParams;
    expect(captured.id, 'ms-1');
    expect(captured.accessToken, 'token-abc');
    await cubit.close();
  });
}
