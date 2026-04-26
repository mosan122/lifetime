import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/get_milestones_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/milestone_timeline_cubit.dart';

class MockGetMilestonesUseCase extends Mock implements GetMilestonesUseCase {}

void main() {
  late MockGetMilestonesUseCase mockGetMilestones;

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

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockGetMilestones = MockGetMilestonesUseCase();
  });

  test('initial state is MilestoneTimelineInitial', () {
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    expect(cubit.state, const MilestoneTimelineInitial());
    cubit.close();
  });

  blocTest<MilestoneTimelineCubit, MilestoneTimelineState>(
    'emits [Loading, Loaded] when getMilestones succeeds',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => Right([tMilestone]));
    },
    build: () => MilestoneTimelineCubit(mockGetMilestones),
    act: (cubit) => cubit.loadTimeline(),
    expect: () => [
      const MilestoneTimelineLoading(),
      MilestoneTimelineLoaded([tMilestone]),
    ],
    verify: (_) {
      verify(() => mockGetMilestones(const NoParams())).called(1);
    },
  );

  blocTest<MilestoneTimelineCubit, MilestoneTimelineState>(
    'emits [Loading, Loaded] with empty list when no milestones exist',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => const Right([]));
    },
    build: () => MilestoneTimelineCubit(mockGetMilestones),
    act: (cubit) => cubit.loadTimeline(),
    expect: () => [
      const MilestoneTimelineLoading(),
      const MilestoneTimelineLoaded([]),
    ],
  );

  blocTest<MilestoneTimelineCubit, MilestoneTimelineState>(
    'emits [Loading, Error] with message and code when repository fails',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('timeout', '500')),
      );
    },
    build: () => MilestoneTimelineCubit(mockGetMilestones),
    act: (cubit) => cubit.loadTimeline(),
    expect: () => [
      const MilestoneTimelineLoading(),
      const MilestoneTimelineError('timeout', code: '500'),
    ],
  );

  blocTest<MilestoneTimelineCubit, MilestoneTimelineState>(
    'emits [Loading, Error] when auth fails',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => const Left(AuthFailure()));
    },
    build: () => MilestoneTimelineCubit(mockGetMilestones),
    act: (cubit) => cubit.loadTimeline(),
    expect: () => [
      const MilestoneTimelineLoading(),
      const MilestoneTimelineError('Authentication error'),
    ],
  );

  blocTest<MilestoneTimelineCubit, MilestoneTimelineState>(
    'emits [Loading, Error] when database fails with code',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async =>
            const Left(DatabaseFailure('connection error', code: '08000')),
      );
    },
    build: () => MilestoneTimelineCubit(mockGetMilestones),
    act: (cubit) => cubit.loadTimeline(),
    expect: () => [
      const MilestoneTimelineLoading(),
      const MilestoneTimelineError('connection error', code: '08000'),
    ],
  );
}
