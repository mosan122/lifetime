import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/create_milestone_cubit.dart';

class MockCreateMilestoneUseCase extends Mock implements CreateMilestoneUseCase {}

void main() {
  late MockCreateMilestoneUseCase mockCreateMilestone;

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
    category: 'general',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  setUpAll(() {
    registerFallbackValue(
      CreateMilestoneParams(userNote: '', eventDate: DateTime(2026)),
    );
  });

  setUp(() {
    mockCreateMilestone = MockCreateMilestoneUseCase();
  });

  test('initial state is CreateMilestoneInitial', () {
    final cubit = CreateMilestoneCubit(mockCreateMilestone);
    expect(cubit.state, const CreateMilestoneInitial());
    cubit.close();
  });

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Success] when createMilestone succeeds',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: () => CreateMilestoneCubit(mockCreateMilestone),
    act: (cubit) => cubit.submit(
      userNote: 'Celebré mi 30 cumpleaños.',
      eventDate: tDate,
    ),
    expect: () => [
      const CreateMilestoneSubmitting(),
      CreateMilestoneSuccess(tMilestone),
    ],
    verify: (_) {
      verify(() => mockCreateMilestone(any())).called(1);
    },
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] when createMilestone returns AuthFailure',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => const Left(AuthFailure()));
    },
    build: () => CreateMilestoneCubit(mockCreateMilestone),
    act: (cubit) => cubit.submit(
      userNote: 'Nota de prueba',
      eventDate: tDate,
    ),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Authentication error'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] with code when createMilestone returns NetworkFailure',
    setUp: () {
      when(() => mockCreateMilestone(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('timeout', '500')),
      );
    },
    build: () => CreateMilestoneCubit(mockCreateMilestone),
    act: (cubit) => cubit.submit(
      userNote: 'Nota de prueba',
      eventDate: tDate,
    ),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('timeout', code: '500'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'emits [Submitting, Error] when biographer service fails',
    setUp: () {
      when(() => mockCreateMilestone(any())).thenAnswer(
        (_) async => const Left(BiographerFailure()),
      );
    },
    build: () => CreateMilestoneCubit(mockCreateMilestone),
    act: (cubit) => cubit.submit(
      userNote: 'Nota de prueba',
      eventDate: tDate,
    ),
    expect: () => [
      const CreateMilestoneSubmitting(),
      const CreateMilestoneError('Biographer service error'),
    ],
  );

  blocTest<CreateMilestoneCubit, CreateMilestoneState>(
    'forwards all optional params to use case',
    setUp: () {
      when(() => mockCreateMilestone(any()))
          .thenAnswer((_) async => Right(tMilestone));
    },
    build: () => CreateMilestoneCubit(mockCreateMilestone),
    act: (cubit) => cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      locationName: 'Madrid',
      latitude: 40.4168,
      longitude: -3.7038,
      category: 'familia',
      participants: ['Ana'],
      isPublic: true,
    ),
    verify: (_) {
      final captured = verify(() => mockCreateMilestone(captureAny())).captured;
      final params = captured.first as CreateMilestoneParams;
      expect(params.locationName, equals('Madrid'));
      expect(params.latitude, equals(40.4168));
      expect(params.category, equals('familia'));
      expect(params.participants, equals(['Ana']));
      expect(params.isPublic, isTrue);
    },
  );
}
