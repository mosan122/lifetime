import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/get_milestones_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/map_cubit.dart';

class MockGetMilestonesUseCase extends Mock implements GetMilestonesUseCase {}

void main() {
  late MockGetMilestonesUseCase mockGetMilestones;

  final tDate = DateTime(2026, 4, 26);

  MilestoneModel makeModel({
    required String id,
    double? latitude,
    double? longitude,
  }) =>
      MilestoneModel(
        id: id,
        userId: 'user-1',
        title: 'Hito $id',
        description: null,
        participants: const [],
        media: const [],
        eventDate: tDate,
        locationName: latitude != null ? 'Lugar $id' : null,
        latitude: latitude,
        longitude: longitude,
        category: 'general',
        isPublic: false,
        createdAt: tDate,
      );

  // Fixtures
  final tLocated1 = makeModel(id: 'ms-1', latitude: 40.4168, longitude: -3.7038);
  final tLocated2 = makeModel(id: 'ms-2', latitude: 41.3874, longitude: 2.1686);
  final tNoLocation = makeModel(id: 'ms-3', latitude: null, longitude: null);
  final tLatOnly = makeModel(id: 'ms-4', latitude: 40.4168, longitude: null);
  final tLngOnly = makeModel(id: 'ms-5', latitude: null, longitude: -3.7038);

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockGetMilestones = MockGetMilestonesUseCase();
  });

  MapCubit buildCubit() => MapCubit(mockGetMilestones);

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial state is MapInitial', () {
    final cubit = buildCubit();
    expect(cubit.state, const MapInitial());
    cubit.close();
  });

  // ── loadMap — success ─────────────────────────────────────────────────────

  blocTest<MapCubit, MapState>(
    'emits [Loading, Loaded] on success',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => Right([tLocated1, tNoLocation]));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    expect: () => [const MapLoading(), isA<MapLoaded>()],
    verify: (_) {
      verify(() => mockGetMilestones(const NoParams())).called(1);
    },
  );

  blocTest<MapCubit, MapState>(
    'locatedMilestones includes only milestones with both lat AND lng',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async =>
            Right([tLocated1, tLocated2, tNoLocation, tLatOnly, tLngOnly]),
      );
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      final state = c.state as MapLoaded;
      expect(state.locatedMilestones, hasLength(2));
      expect(
        state.locatedMilestones.map((m) => m.id),
        containsAll(['ms-1', 'ms-2']),
      );
    },
  );

  blocTest<MapCubit, MapState>(
    'allMilestones contains every milestone regardless of location',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async => Right([tLocated1, tNoLocation, tLatOnly, tLngOnly]),
      );
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      expect((c.state as MapLoaded).allMilestones, hasLength(4));
    },
  );

  blocTest<MapCubit, MapState>(
    'locatedMilestones is empty when no milestone has coordinates',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async => Right([tNoLocation, tLatOnly, tLngOnly]),
      );
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      expect((c.state as MapLoaded).locatedMilestones, isEmpty);
    },
  );

  blocTest<MapCubit, MapState>(
    'milestone with only latitude is excluded from locatedMilestones',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => Right([tLatOnly]));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      expect((c.state as MapLoaded).locatedMilestones, isEmpty);
    },
  );

  blocTest<MapCubit, MapState>(
    'milestone with only longitude is excluded from locatedMilestones',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => Right([tLngOnly]));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      expect((c.state as MapLoaded).locatedMilestones, isEmpty);
    },
  );

  blocTest<MapCubit, MapState>(
    'both lists are empty when repository returns empty list',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => const Right([]));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      final state = c.state as MapLoaded;
      expect(state.allMilestones, isEmpty);
      expect(state.locatedMilestones, isEmpty);
    },
  );

  blocTest<MapCubit, MapState>(
    'all milestones end up in locatedMilestones when all have coordinates',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => Right([tLocated1, tLocated2]));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    verify: (c) {
      final state = c.state as MapLoaded;
      expect(state.locatedMilestones, hasLength(2));
      expect(state.allMilestones.length, equals(state.locatedMilestones.length));
    },
  );

  // ── loadMap — failure ─────────────────────────────────────────────────────

  blocTest<MapCubit, MapState>(
    'emits [Loading, Error] on NetworkFailure',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('timeout', '500')),
      );
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    expect: () => [
      const MapLoading(),
      const MapError('timeout', code: '500'),
    ],
  );

  blocTest<MapCubit, MapState>(
    'emits [Loading, Error] on AuthFailure',
    setUp: () {
      when(() => mockGetMilestones(any()))
          .thenAnswer((_) async => const Left(AuthFailure()));
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    expect: () => [
      const MapLoading(),
      const MapError('Authentication error'),
    ],
  );

  blocTest<MapCubit, MapState>(
    'emits [Loading, Error] on DatabaseFailure with code',
    setUp: () {
      when(() => mockGetMilestones(any())).thenAnswer(
        (_) async =>
            const Left(DatabaseFailure('connection error', code: '08000')),
      );
    },
    build: buildCubit,
    act: (c) => c.loadMap(),
    expect: () => [
      const MapLoading(),
      const MapError('connection error', code: '08000'),
    ],
  );

  // ── MapLoaded equality ────────────────────────────────────────────────────

  group('MapLoaded equality', () {
    test('equal when same milestones', () {
      final a = MapLoaded(
        allMilestones: [tLocated1],
        locatedMilestones: [tLocated1],
      );
      final b = MapLoaded(
        allMilestones: [tLocated1],
        locatedMilestones: [tLocated1],
      );
      expect(a, equals(b));
    });

    test('not equal when locatedMilestones differ', () {
      final a = MapLoaded(
        allMilestones: [tLocated1, tLocated2],
        locatedMilestones: [tLocated1],
      );
      final b = MapLoaded(
        allMilestones: [tLocated1, tLocated2],
        locatedMilestones: [tLocated2],
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ── MapError equality ─────────────────────────────────────────────────────

  group('MapError equality', () {
    test('equal when same message and code', () {
      expect(
        const MapError('timeout', code: '500'),
        equals(const MapError('timeout', code: '500')),
      );
    });

    test('not equal when code differs', () {
      expect(
        const MapError('error', code: '500'),
        isNot(equals(const MapError('error', code: '503'))),
      );
    });
  });
}
