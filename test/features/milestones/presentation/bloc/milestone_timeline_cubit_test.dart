import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/entities/milestone.dart';
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
    categoryId: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  final tMilestone2 = MilestoneModel(
    id: 'ms-2',
    userId: 'user-1',
    title: 'Otro hito',
    description: null,
    participants: const [],
    media: const [],
    eventDate: DateTime(2026, 5, 1),
    locationName: null,
    latitude: null,
    longitude: null,
    categoryId: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 5, 1, 10),
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(<Milestone>[]);
  });

  setUp(() {
    mockGetMilestones = MockGetMilestonesUseCase();
  });

  test('initial state is MilestoneTimelineInitial', () {
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    expect(cubit.state, const MilestoneTimelineInitial());
    cubit.close();
  });

  test('emits [Loading, Loaded] when getMilestones succeeds', () async {
    when(() => mockGetMilestones(any()))
        .thenAnswer((_) async => Right([tMilestone]));
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        MilestoneTimelineLoaded([tMilestone]),
      ]),
    );
    await cubit.loadTimeline();
    await done;
    await cubit.close();
    verify(() => mockGetMilestones(const NoParams())).called(1);
  });

  test('emits [Loading, Loaded] with empty list when no milestones exist',
      () async {
    when(() => mockGetMilestones(any()))
        .thenAnswer((_) async => const Right([]));
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        const MilestoneTimelineLoaded([]),
      ]),
    );
    await cubit.loadTimeline();
    await done;
    await cubit.close();
  });

  test('emits [Loading, Error] with message and code when repository fails',
      () async {
    when(() => mockGetMilestones(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('timeout', '500')),
    );
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        const MilestoneTimelineError('timeout', code: '500'),
      ]),
    );
    await cubit.loadTimeline();
    await done;
    await cubit.close();
  });

  test('emits [Loading, Error] when auth fails', () async {
    when(() => mockGetMilestones(any()))
        .thenAnswer((_) async => const Left(AuthFailure()));
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        const MilestoneTimelineError('Authentication error'),
      ]),
    );
    await cubit.loadTimeline();
    await done;
    await cubit.close();
  });

  test('emits [Loading, Error] when database fails with code', () async {
    when(() => mockGetMilestones(any())).thenAnswer(
      (_) async =>
          const Left(DatabaseFailure('connection error', code: '08000')),
    );
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        const MilestoneTimelineError('connection error', code: '08000'),
      ]),
    );
    await cubit.loadTimeline();
    await done;
    await cubit.close();
  });

  test('refreshTimeline from Loaded re-fetches without Loading', () async {
    var calls = 0;
    when(() => mockGetMilestones(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return Right([tMilestone]);
      }
      return Right([tMilestone, tMilestone2]);
    });
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    await cubit.loadTimeline();
    expect(cubit.state, MilestoneTimelineLoaded([tMilestone]));

    final done = expectLater(
      cubit.stream,
      emits(MilestoneTimelineLoaded([tMilestone, tMilestone2])),
    );
    await cubit.refreshTimeline();
    await done;
    await cubit.close();
    verify(() => mockGetMilestones(const NoParams())).called(2);
  });

  test('refreshTimeline from Initial runs full loadTimeline', () async {
    when(() => mockGetMilestones(any()))
        .thenAnswer((_) async => Right([tMilestone]));
    final cubit = MilestoneTimelineCubit(mockGetMilestones);
    final done = expectLater(
      cubit.stream,
      emitsInOrder([
        const MilestoneTimelineLoading(),
        MilestoneTimelineLoaded([tMilestone]),
      ]),
    );
    await cubit.refreshTimeline();
    await done;
    await cubit.close();
  });
}
