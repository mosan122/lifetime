import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'package:lifetime/features/milestones/presentation/bloc/create_milestone_cubit.dart';

class MockCreateMilestoneUseCase extends Mock implements CreateMilestoneUseCase {}

class MockPremiumService extends Mock implements PremiumService {}

void main() {
  late MockCreateMilestoneUseCase mockCreateMilestone;
  late MockPremiumService mockPremium;

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
    categoryId: 'otros',
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
    mockPremium = MockPremiumService();
    when(() => mockPremium.isPremium).thenReturn(true);
  });

  CreateMilestoneCubit buildCubit() =>
      CreateMilestoneCubit(mockCreateMilestone, mockPremium);

  Future<List<CreateMilestoneState>> collectEmissionsDuring(
    CreateMilestoneCubit cubit,
    Future<void> Function() run,
  ) async {
    final emissions = <CreateMilestoneState>[];
    final sub = cubit.stream.listen(emissions.add);
    await run();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return emissions;
  }

  test('initial state is CreateMilestoneInitial', () {
    final cubit = buildCubit();
    expect(cubit.state, const CreateMilestoneInitial());
    return cubit.close();
  });

  test('emits [Submitting, Success] when no media and createMilestone succeeds',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Celebré mi 30 cumpleaños.',
        eventDate: tDate,
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Guardando hito…'),
      CreateMilestoneSuccess(tMilestone),
    ]);
    verify(() => mockCreateMilestone(any())).called(1);
    await cubit.close();
  });

  test('emits [Submitting, Error] when createMilestone returns AuthFailure',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => const Left(AuthFailure()));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Guardando hito…'),
      const CreateMilestoneError('Authentication error'),
    ]);
    await cubit.close();
  });

  test(
      'emits [Submitting, Error] with code when createMilestone returns NetworkFailure',
      () async {
    when(() => mockCreateMilestone(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('timeout', '500')),
    );
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Guardando hito…'),
      const CreateMilestoneError('timeout', code: '500'),
    ]);
    await cubit.close();
  });

  test('emits [Submitting, Error] when biographer service fails', () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => const Left(BiographerFailure()));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Guardando hito…'),
      const CreateMilestoneError('Biographer service error'),
    ]);
    await cubit.close();
  });

  test('forwards all optional params to use case', () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    await cubit.submit(
      userNote: 'Nota',
      eventDate: tDate,
      locationName: 'Madrid',
      latitude: 40.4168,
      longitude: -3.7038,
      categoryId: 'familia',
      participants: ['Ana'],
      isPublic: true,
    );
    final captured = verify(() => mockCreateMilestone(captureAny())).captured;
    final params = captured.first as CreateMilestoneParams;
    expect(params.locationName, equals('Madrid'));
    expect(params.latitude, equals(40.4168));
    expect(params.categoryId, equals('familia'));
    expect(params.participants, equals(['Ana']));
    expect(params.isPublic, isTrue);
    expect(params.driveFileId, isNull);
    await cubit.close();
  });

  test(
      'does not upload to Drive on submit; media is deferred to CloudSyncService',
      () async {
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(
        userNote: 'Foto.',
        eventDate: tDate,
        mediaFiles: [File('/tmp/photo.jpg')],
      ),
    );
    expect(emissions, [
      const CreateMilestoneSubmitting('Guardando hito…'),
      CreateMilestoneSuccess(tMilestone),
    ]);
    final captured = verify(() => mockCreateMilestone(captureAny())).captured;
    final params = captured.first as CreateMilestoneParams;
    expect(params.driveFileId, isNull);
    await cubit.close();
  });

  test('free user uses redact submitting label', () async {
    when(() => mockPremium.isPremium).thenReturn(false);
    when(() => mockCreateMilestone(any()))
        .thenAnswer((_) async => Right(tMilestone));
    final cubit = buildCubit();
    final emissions = await collectEmissionsDuring(
      cubit,
      () => cubit.submit(userNote: 'Nota', eventDate: tDate),
    );
    expect(emissions.first, const CreateMilestoneSubmitting('Redactando historia...'));
    await cubit.close();
  });
}
