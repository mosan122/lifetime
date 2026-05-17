// test/data/repositories/milestone_repository_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/local_media_store.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/data/datasources/milestone_remote_datasource.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/data/repositories/milestone_repository_impl.dart';
import 'package:lifetime/domain/repositories/drive_repository.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_category_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_person_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_relationship_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_saved_location_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/person_group_local_datasource.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

class MockIsarMilestoneDataSource extends Mock
    implements IsarMilestoneDataSource {}

class MockMilestoneRemoteDataSource extends Mock
    implements MilestoneRemoteDataSource {}

class MockPremiumService extends Mock implements PremiumService {}
class MockDriveRepository extends Mock implements DriveRepository {}
class MockLocalMediaStore extends Mock implements LocalMediaStore {}
class MockIsarPersonDataSource extends Mock implements IsarPersonDataSource {}
class MockIsarCategoryDataSource extends Mock implements IsarCategoryDataSource {}
class MockIsarSavedLocationDataSource extends Mock
    implements IsarSavedLocationDataSource {}
class MockIsarRelationshipDataSource extends Mock
    implements IsarRelationshipDataSource {}
class MockPersonGroupLocalDataSource extends Mock
    implements PersonGroupLocalDataSource {}

class FakeMilestoneCollection extends Fake implements MilestoneCollection {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMilestoneCollection());
  });

  late MockIsarMilestoneDataSource mockLocal;
  late MockMilestoneRemoteDataSource mockRemote;
  late MockPremiumService mockPremium;
  late MockDriveRepository mockDrive;
  late MockLocalMediaStore mockLocalMedia;
  late MockIsarPersonDataSource mockPerson;
  late MockIsarCategoryDataSource mockCategory;
  late MockIsarSavedLocationDataSource mockSavedLoc;
  late MockIsarRelationshipDataSource mockRel;
  late MockPersonGroupLocalDataSource mockPersonGroup;
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
    participants: const [],
    participantIds: const ['p-ana'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    categoryId: 'familia',
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

  final tMilestoneWithDrive = MilestoneModel(
    id: 'ms-2',
    userId: 'user-1',
    title: 'Viaje memorable',
    description: 'Un día genial',
    participants: const [],
    participantIds: const ['p-ana'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    categoryId: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
    driveFileId: 'drive-file-123',
  );

  final tCollectionWithDrive = MilestoneCollection.fromMilestone(
    tMilestoneWithDrive,
    SyncStatus.synced,
  );

  setUp(() {
    mockLocal = MockIsarMilestoneDataSource();
    mockRemote = MockMilestoneRemoteDataSource();
    mockPremium = MockPremiumService();
    mockDrive = MockDriveRepository();
    mockLocalMedia = MockLocalMediaStore();
    mockPerson = MockIsarPersonDataSource();
    mockCategory = MockIsarCategoryDataSource();
    mockSavedLoc = MockIsarSavedLocationDataSource();
    mockRel = MockIsarRelationshipDataSource();
    mockPersonGroup = MockPersonGroupLocalDataSource();
    repository = MilestoneRepositoryImpl(
      mockLocal,
      mockRemote,
      mockPremium,
      () => 'user-1',
      mockDrive,
      mockLocalMedia,
      mockPerson,
      mockCategory,
      mockSavedLoc,
      mockRel,
      mockPersonGroup,
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
      when(() => mockLocal.fetchDeleted()).thenAnswer((_) async => []);

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
      when(() => mockLocal.fetchDeleted()).thenAnswer((_) async => []);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) => expect(list, isEmpty));
    });

    test('seeds from Supabase when premium + Isar empty, then returns those milestones',
        () async {
      stubPremium(true);
      var fetchAllCalls = 0;
      when(() => mockLocal.fetchAll()).thenAnswer((_) async {
        fetchAllCalls++;
        return fetchAllCalls == 1 ? <MilestoneCollection>[] : [tCollection];
      });
      when(() => mockLocal.fetchDeleted()).thenAnswer((_) async => []);
      when(() => mockLocal.fetchCollectionById(any()))
          .thenAnswer((_) async => null);
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

    test('does not re-seed from Supabase when only soft-deleted milestones remain',
        () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll()).thenAnswer((_) async => []);
      when(() => mockLocal.fetchDeleted())
          .thenAnswer((_) async => [tCollection..isDeleted = true]);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) => expect(list, isEmpty));
    });

    test('does NOT call remote when premium + Isar non-empty', () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll())
          .thenAnswer((_) async => [tCollection]);
      when(() => mockLocal.fetchDeleted()).thenAnswer((_) async => []);

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
      expect(captured!.eventDate, equals(tDate));
      expect(captured!.description, equals(tUserNote));
      expect(captured!.locationName, equals(tLocationName));
    });

    test('title uses description fallback when empty title', () async {
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      await repository.createMilestone(
        userNote: 'Nota libre.',
        eventDate: DateTime(2026, 4, 26),
      );

      expect(captured!.title, equals('Nota libre.'));
    });
  });

  // ─── createMilestone — Premium online ────────────────────────────────────

  group('createMilestone — premium online', () {
    setUp(() => stubPremium(true));

    test('saves local-first as pending; biographer updates; no remote insert',
        () async {
      stubBiographerSuccess();
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });
      when(() => mockLocal.fetchCollectionById(any())).thenAnswer((_) async {
        return captured;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        participants: ['Ana'],
      );

      expect(result.isRight(), isTrue);
      verifyNever(() => mockRemote.insertMilestone(any()));
      expect(captured!.syncStatus, equals(SyncStatus.pending));
      expect(captured!.isSynced, isFalse);
      expect(captured!.eventDate, equals(tDate));
      expect(captured!.locationName, equals(tLocationName));
    });

    test('persists lat/lng on local location embed when provided', () async {
      stubBiographerSuccess();
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });
      when(() => mockLocal.fetchCollectionById(any()))
          .thenAnswer((_) async => captured);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(captured!.location?.latitude, closeTo(40.4168, 0.0001));
      expect(captured!.location?.longitude, closeTo(-3.7038, 0.0001));
      verifyNever(() => mockRemote.insertMilestone(any()));
    });
  });

  // ─── createMilestone — Premium offline ───────────────────────────────────

  group('createMilestone — premium offline', () {
    setUp(() => stubPremium(true));

    test('returns Right and saves as pending when biographer throws after local save',
        () async {
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
      verifyNever(() => mockRemote.insertMilestone(any()));
    });

  });

  // ─── deleteMilestone ─────────────────────────────────────────────────────

  group('deleteMilestone', () {
    test('free user: deletes from local only', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById(any())).thenAnswer((_) async => tCollection);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});
      when(() => mockLocalMedia.deleteFolder(any(), any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1')).called(1);
      verify(() => mockLocalMedia.deleteFolder(tDate, 'ms-1')).called(1);
      verifyNever(() => mockRemote.deleteMilestone(any()));
      verifyNever(() => mockDrive.deleteFile(
            fileId: any(named: 'fileId'),
            accessToken: any(named: 'accessToken'),
          ));
    });

    test('premium user: soft-deletes locally (sync purges remote later)', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.deleteById('ms-1', softDelete: true))
          .thenAnswer((_) async {});
      when(() => mockLocalMedia.deleteFolder(any(), any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1', softDelete: true)).called(1);
      verify(() => mockLocalMedia.deleteFolder(tDate, 'ms-1')).called(1);
      verifyNever(() => mockRemote.deleteMilestone(any()));
    });

    test('premium user: soft-delete returns Right even if local throws', () async {
      stubPremium(true);
      when(() => mockLocal.deleteById('ms-1', softDelete: true))
          .thenThrow(Exception('local error'));

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isLeft(), isTrue);
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
        title: 'Título',
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
        title: 'Título',
        description: 'Relato actualizado.',
        locationName: 'Barcelona',
        latitude: 41.3851,
        longitude: 2.1734,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (m) {
          expect(m.id, tMilestoneModel.id);
          expect(m.title, tMilestoneModel.title);
          expect(m.description, tMilestoneModel.description);
          // Tras el remoto, dominio refleja el modelo devuelto por Supabase (stub).
          expect(m.locationName, tMilestoneModel.locationName);
          expect(m.latitude, tMilestoneModel.latitude);
          expect(m.longitude, tMilestoneModel.longitude);
          expect(m.participantIds, tMilestoneModel.participantIds);
        },
      );
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
        title: 'Título',
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
        title: 'Título',
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
        title: 'Título',
        description: 'test',
      );

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<DatabaseFailure>()), (_) => fail('Expected Left'));
    });

    test('updates existing record in-place: same id, new date/location, upsert called once', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final newDate = DateTime(2026, 5, 10);
      await repository.updateMilestone(
        id: 'ms-1',
        title: 'Título',
        description: 'Relato editado.',
        eventDate: newDate,
        locationName: 'Barcelona',
      );

      verify(() => mockLocal.upsert(any())).called(1);
      expect(captured!.id, equals('ms-1'));
      expect(captured!.description, equals('Relato editado.'));
      expect(captured!.eventDate, equals(newDate));
      expect(captured!.locationName, equals('Barcelona'));
    });
  });
}
