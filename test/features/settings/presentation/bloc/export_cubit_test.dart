import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/features/milestones/domain/usecases/export_bitacora_usecase.dart';
import 'package:lifetime/features/settings/presentation/bloc/export_cubit.dart';

class MockExportBitacoraUseCase extends Mock implements ExportBitacoraUseCase {}

void main() {
  late MockExportBitacoraUseCase mockUseCase;
  late ExportCubit cubit;

  const tResult = ExportResult(
    json: '{"version":"1.0","milestones":[]}',
    markdown: '# Mi Bitácora — LifeTime',
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockUseCase = MockExportBitacoraUseCase();
    cubit = ExportCubit(mockUseCase);
  });

  tearDown(() => cubit.close());

  test('initial state is ExportIdle', () {
    expect(cubit.state, const ExportIdle());
  });

  blocTest<ExportCubit, ExportState>(
    'export emits [ExportLoading, ExportReady] on success',
    build: () {
      when(() => mockUseCase(any()))
          .thenAnswer((_) async => const Right(tResult));
      return ExportCubit(mockUseCase);
    },
    act: (c) => c.export(),
    expect: () => [const ExportLoading(), const ExportReady(tResult)],
  );

  blocTest<ExportCubit, ExportState>(
    'export emits [ExportLoading, ExportError] when use case returns Left',
    build: () {
      when(() => mockUseCase(any()))
          .thenAnswer((_) async => const Left(NetworkFailure('timeout')));
      return ExportCubit(mockUseCase);
    },
    act: (c) => c.export(),
    expect: () => [
      const ExportLoading(),
      const ExportError('timeout'),
    ],
  );

  blocTest<ExportCubit, ExportState>(
    'export emits [ExportLoading, ExportError] when use case throws unexpectedly',
    build: () {
      when(() => mockUseCase(any())).thenThrow(Exception('crash'));
      return ExportCubit(mockUseCase);
    },
    act: (c) => c.export(),
    expect: () => [const ExportLoading(), isA<ExportError>()],
  );

  blocTest<ExportCubit, ExportState>(
    'ExportReady holds the ExportResult returned by the use case',
    build: () {
      when(() => mockUseCase(any()))
          .thenAnswer((_) async => const Right(tResult));
      return ExportCubit(mockUseCase);
    },
    act: (c) => c.export(),
    verify: (c) {
      final state = c.state;
      expect(state, isA<ExportReady>());
      expect((state as ExportReady).result, equals(tResult));
    },
  );

  test('ExportIdle equality', () {
    expect(const ExportIdle(), equals(const ExportIdle()));
  });

  test('ExportLoading equality', () {
    expect(const ExportLoading(), equals(const ExportLoading()));
  });

  test('ExportReady equality holds for same result', () {
    expect(
      const ExportReady(tResult),
      equals(const ExportReady(tResult)),
    );
  });

  test('ExportError equality holds for same message', () {
    expect(
      const ExportError('msg'),
      equals(const ExportError('msg')),
    );
  });

  test('ExportError message is accessible', () {
    const state = ExportError('something went wrong');
    expect(state.message, equals('something went wrong'));
  });
}
