// test/data/repositories/milestone_repository_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/data/datasources/milestone_remote_datasource.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/data/repositories/milestone_repository_impl.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

class MockIsarMilestoneDataSource extends Mock
    implements IsarMilestoneDataSource {}

class MockMilestoneRemoteDataSource extends Mock
    implements MilestoneRemoteDataSource {}

class MockPremiumService extends Mock implements PremiumService {}

class FakeMilestoneCollection extends Fake implements MilestoneCollection {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMilestoneCollection());
  });

  late MockIsarMilestoneDataSource mockLocal;
  late MockMilestoneRemoteDataSource mockRemote;
  late MockPremiumService mockPremium;
  late MilestoneRepositoryImpl repository;

  final tDate = DateTime(2026, 4, 26);
  const tUserNote = 'Celebré mi 30 cumpleaños con amigos.';
  const tLocationName = 'Madrid';

  const tBiographerResult =
      (title: 'Mi 30 cumpleaños', narrative: 'Fue un día especial.');

  final tMilestoneModel = MilestoneModel(
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

  final tCollection = MilestoneCollection.fromMilestone(
    tMilestoneModel,
    SyncStatus.synced,
  );

  final tPendingCollection = MilestoneCollection.fromMilestone(
    tMilestoneModel,
    SyncStatus.pending,
  );

  setUp(() {
    mockLocal = MockIsarMilestoneDataSource();
    mockRemote = MockMilestoneRemoteDataSource();
    mockPremium = MockPremiumService();
    repository = MilestoneRepositoryImpl(
      mockLocal,
      mockRemote,
      mockPremium,
      () => 'user-1',
    );
  });

  void stubPremium(bool value) {
    when(() => mockPremium.isPremium).thenReturn(value);
  }

  void stubBiographerSuccess() {
    when(() => mockRemote.callBiographerNarrative(
          userNote: any(named: 'userNote'),
          date: any(named: 'date'),
          location: any(named: 'location'),
          imageBase64: any(named: 'imageBase64'),
        )).thenAnswer((_) async => tBiographerResult);
  }

  // ─── getMilestones ────────────────────────────────────────────────────────

  group('getMilestones', () {
    test('returns local data when Isar is non-empty (free user)', () async {
      stubPremium(false);
      when(() => mockLocal.fetchAll())
          .thenAnswer((_) async => [tCollection]);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) {
        expect(list, hasLength(1));
        expect(list.first.id, equals('ms-1'));
      });
    });

    test('returns empty list for free user with empty Isar', () async {
      stubPremium(false);
      when(() => mockLocal.fetchAll()).thenAnswer((_) async => []);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) => expect(list, isEmpty));
    });

    test('seeds from Supabase when premium + Isar empty, then returns those milestones',
        () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll()).thenAnswer((_) async => []);
      when(() => mockRemote.fetchMilestones())
          .thenAnswer((_) async => [tMilestoneModel]);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      final result = await repository.getMilestones();

      verify(() => mockRemote.fetchMilestones()).called(1);
      verify(() => mockLocal.upsert(any())).called(1);
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) {
        expect(list, hasLength(1));
      });
    });

    test('does NOT call remote when premium + Isar non-empty', () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll())
          .thenAnswer((_) async => [tCollection]);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
    });
  });

  // ─── createMilestone — Free user ──────────────────────────────────────────

  group('createMilestone — free user', () {
    setUp(() => stubPremium(false));

    test('never calls biographer or remote insert', () async {
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tPendingCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      verifyNever(() => mockRemote.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
            imageBase64: any(named: 'imageBase64'),
          ));
      verifyNever(() => mockRemote.insertMilestone(any()));
    });

    test('calls local.upsert with a pending collection', () async {
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        participants: ['Ana'],
      );

      expect(result.isRight(), isTrue);
      expect(captured, isNotNull);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
      expect(captured!.description, equals(tUserNote));
      expect(captured!.locationName, equals(tLocationName));
    });

    test('title uses date-based fallback', () async {
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      await repository.createMilestone(
        userNote: 'Nota libre.',
        eventDate: DateTime(2026, 4, 26),
      );

      expect(captured!.title, contains('26'));
      expect(captured!.title, contains('2026'));
    });
  });

  // ─── createMilestone — Premium online ────────────────────────────────────

  group('createMilestone — premium online', () {
    setUp(() => stubPremium(true));

    test('calls biographer + remote insert, upserts locally as synced', () async {
      stubBiographerSuccess();
      when(() => mockRemote.insertMilestone(any()))
          .thenAnswer((_) async => tMilestoneModel);
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        participants: ['Ana'],
      );

      expect(result, Right(tMilestoneModel));
      expect(captured!.syncStatus, equals(SyncStatus.synced));
    });

    test('insert map contains POINT WKT when lat/lng provided', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('insert map omits location_coords when lat/lng are null', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(capturedData!.containsKey('location_coords'), isFalse);
    });
  });

  // ─── createMilestone — Premium offline ───────────────────────────────────

  group('createMilestone — premium offline', () {
    setUp(() => stubPremium(true));

    test('returns Right and saves as pending when remote insert throws', () async {
      stubBiographerSuccess();
      when(() => mockRemote.insertMilestone(any()))
          .thenThrow(Exception('Network error'));
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
    });

    test('saves as pending when biographer also throws (full offline)', () async {
      when(() => mockRemote.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
            imageBase64: any(named: 'imageBase64'),
          )).thenThrow(Exception('Biographer unreachable'));
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
      verify(() => mockLocal.upsert(any())).called(1);
      verifyNever(() => mockRemote.insertMilestone(any()));
    });
  });

  // ─── deleteMilestone ─────────────────────────────────────────────────────

  group('deleteMilestone', () {
    test('free user: deletes from local only', () async {
      stubPremium(false);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1')).called(1);
      verifyNever(() => mockRemote.deleteMilestone(any()));
    });

    test('premium user: deletes from local and attempts remote', () async {
      stubPremium(true);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});
      when(() => mockRemote.deleteMilestone(any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1')).called(1);
      verify(() => mockRemote.deleteMilestone('ms-1')).called(1);
    });

    test('premium user: still returns Right when remote delete throws', () async {
      stubPremium(true);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});
      when(() => mockRemote.deleteMilestone(any()))
          .thenThrow(Exception('Network error'));

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
    });
  });

  // ─── updateMilestone ──────────────────────────────────────────────────────

  group('updateMilestone', () {
    test('free user: updates local as pending', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tPendingCollection);

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Relato actualizado.',
      );

      expect(result.isRight(), isTrue);
      verifyNever(() => mockRemote.updateMilestone(any(), any()));
    });

    test('premium online: updates local + remote, upserts as synced', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Relato actualizado.',
        locationName: 'Barcelona',
        latitude: 41.3851,
        longitude: 2.1734,
      );

      expect(result, Right(tMilestoneModel));
      verify(() => mockRemote.updateMilestone('ms-1', any())).called(1);
    });

    test('update map has correct WKT longitude-first order', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenAnswer((inv) async {
        capturedData = inv.positionalArguments[1] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.updateMilestone(
        id: 'ms-1',
        description: 'WKT test.',
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('premium offline: saves locally as pending when remote throws', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenThrow(Exception('Network error'));

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Offline update.',
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
    });

    test('returns Left(DatabaseFailure) when item not found locally', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById(any())).thenAnswer((_) async => null);

      final result = await repository.updateMilestone(
        id: 'nonexistent',
        description: 'test',
      );

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<DatabaseFailure>()), (_) => fail('Expected Left'));
    });
  });
}
