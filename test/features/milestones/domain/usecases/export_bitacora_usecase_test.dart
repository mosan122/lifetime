import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/core/utils/bitacora_backup_json.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_category_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_person_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_relationship_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_saved_location_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/person_group_local_datasource.dart';
import 'package:lifetime/features/milestones/domain/usecases/export_bitacora_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}
class MockIsarPersonDataSource extends Mock implements IsarPersonDataSource {}
class MockIsarCategoryDataSource extends Mock implements IsarCategoryDataSource {}
class MockIsarSavedLocationDataSource extends Mock
    implements IsarSavedLocationDataSource {}
class MockIsarRelationshipDataSource extends Mock
    implements IsarRelationshipDataSource {}
class MockPersonGroupLocalDataSource extends Mock
    implements PersonGroupLocalDataSource {}

void main() {
  final tDate = DateTime(2026, 4, 26);

  MilestoneModel makeMilestone({
    String id = 'ms-1',
    String title = 'Mi 30 cumpleaños',
    String? description = 'Fue un día especial.',
    String? locationName = 'Madrid',
    double? latitude = 40.4168,
    double? longitude = -3.7038,
    List<String> participantIds = const ['Ana', 'Luis'],
    String? driveFileId,
  }) =>
      MilestoneModel(
        id: id,
        userId: 'user-1',
        title: title,
        description: description,
        participantIds: participantIds,
        media: const [],
        eventDate: tDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        categoryId: 'familia',
        isPublic: false,
        createdAt: tDate,
        driveFileId: driveFileId,
      );

  // ── BitacoraBackupJson.encode ───────────────────────────────────────────────

  group('BitacoraBackupJson.encode', () {
    test('produces valid JSON that does not throw on decode', () {
      expect(
        () => jsonDecode(BitacoraBackupJson.encode(
          [makeMilestone()],
          const BitacoraExportBundles(),
        )),
        returnsNormally,
      );
    });

    test('contains version 3.0 and bitacora schema', () {
      final data = jsonDecode(BitacoraBackupJson.encode(
        [],
        const BitacoraExportBundles(),
      )) as Map;
      expect(data['version'], equals('3.0'));
      expect(data['schema'], equals('bitacora'));
      expect(data['people'], isA<List>());
      expect(data['custom_categories'], isA<List>());
    });

    test('legacy encode keeps version 2.0', () {
      final data = jsonDecode(BitacoraBackupJson.encodeLegacyMilestonesOnly([]))
          as Map;
      expect(data['version'], equals('2.0'));
      expect(data['schema'], equals('bitacora_milestones'));
    });

    test('contains exported_at field', () {
      final data = jsonDecode(BitacoraBackupJson.encode(
        [],
        const BitacoraExportBundles(),
      )) as Map;
      expect(data['exported_at'], isNotNull);
    });

    test('total matches milestone count', () {
      final data = jsonDecode(BitacoraBackupJson.encode(
        [makeMilestone(), makeMilestone(id: 'ms-2')],
      )) as Map;
      expect(data['total'], equals(2));
    });

    test('empty list produces total 0 and empty array', () {
      final data = jsonDecode(BitacoraBackupJson.encode(
        [],
        const BitacoraExportBundles(),
      )) as Map;
      expect(data['total'], equals(0));
      expect((data['milestones'] as List), isEmpty);
    });

    test('title is present in milestone entry', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      expect((data['milestones'] as List)[0]['title'], equals('Mi 30 cumpleaños'));
    });

    test('description (narrative) is present in milestone entry', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      expect((data['milestones'] as List)[0]['description'], equals('Fue un día especial.'));
    });

    test('event_date is formatted as YYYY-MM-DD', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      expect((data['milestones'] as List)[0]['event_date'], equals('2026-04-26'));
    });

    test('location contains latitude and longitude when coords are present', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      final loc = (data['milestones'] as List)[0]['location'] as Map;
      expect(loc['latitude'], equals(40.4168));
      expect(loc['longitude'], equals(-3.7038));
    });

    test('location contains name when locationName is set', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      final loc = (data['milestones'] as List)[0]['location'] as Map;
      expect(loc['name'], equals('Madrid'));
    });

    test('location is null when latitude and longitude are null', () {
      final data = jsonDecode(BitacoraBackupJson.encode([
        makeMilestone(latitude: null, longitude: null, locationName: null),
      ], const BitacoraExportBundles())) as Map;
      expect((data['milestones'] as List)[0]['location'], isNull);
    });

    test('participant_ids list is included', () {
      final data = jsonDecode(BitacoraBackupJson.encode([makeMilestone()],
          const BitacoraExportBundles())) as Map;
      expect(
        (data['milestones'] as List)[0]['participant_ids'],
        equals(['Ana', 'Luis']),
      );
    });

    test('drive_file_id is included when present', () {
      final data = jsonDecode(BitacoraBackupJson.encode(
        [makeMilestone(driveFileId: 'drive-abc')],
        const BitacoraExportBundles(),
      )) as Map;
      expect((data['milestones'] as List)[0]['drive_file_id'], equals('drive-abc'));
    });
  });

  // ── toMarkdown ───────────────────────────────────────────────────────────────

  group('ExportBitacoraUseCase.toMarkdown', () {
    test('starts with YAML frontmatter delimiters', () {
      final md = ExportBitacoraUseCase.toMarkdown([]);
      expect(md.trimLeft(), startsWith('---'));
    });

    test('frontmatter contains app: LifeTime', () {
      final md = ExportBitacoraUseCase.toMarkdown([]);
      expect(md, contains('app: LifeTime'));
    });

    test('frontmatter contains export_date field', () {
      final md = ExportBitacoraUseCase.toMarkdown([]);
      expect(md, contains('export_date:'));
    });

    test('contains H1 header with LifeTime', () {
      final md = ExportBitacoraUseCase.toMarkdown([]);
      expect(md, contains('# Mi Bitácora — LifeTime'));
    });

    test('milestone title appears as H2', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('## Mi 30 cumpleaños'));
    });

    test('contains event date with calendar emoji', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('📅'));
      expect(md, contains('26/04/2026'));
    });

    test('contains description (narrative)', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('Fue un día especial.'));
    });

    test('contains location name with pin emoji when coords are set', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('📍'));
      expect(md, contains('Madrid'));
    });

    test('contains latitude and longitude in location line', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('40.4168'));
      expect(md, contains('-3.7038'));
    });

    test('omits location block when latitude and longitude are null', () {
      final md = ExportBitacoraUseCase.toMarkdown([
        makeMilestone(latitude: null, longitude: null, locationName: null),
      ]);
      expect(md, isNot(contains('📍')));
    });

    test('contains participants with group emoji when list is non-empty', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, contains('👥'));
      expect(md, contains('Ana'));
      expect(md, contains('Luis'));
    });

    test('omits participants line when list is empty', () {
      final md = ExportBitacoraUseCase.toMarkdown([
        makeMilestone(participantIds: []),
      ]);
      expect(md, isNot(contains('👥')));
    });

    test('contains Drive link when driveFileId is set', () {
      final md = ExportBitacoraUseCase.toMarkdown([
        makeMilestone(driveFileId: 'drive-xyz'),
      ]);
      expect(md, contains('https://drive.google.com/open?id=drive-xyz'));
    });

    test('omits Drive link when driveFileId is null', () {
      final md = ExportBitacoraUseCase.toMarkdown([makeMilestone()]);
      expect(md, isNot(contains('drive.google.com')));
    });

    test('empty list produces non-empty Markdown with header', () {
      final md = ExportBitacoraUseCase.toMarkdown([]);
      expect(md, isNotEmpty);
      expect(md, contains('LifeTime'));
    });
  });

  // ── use case (call) ──────────────────────────────────────────────────────────

  group('ExportBitacoraUseCase.call', () {
    late MockMilestoneRepository mockRepository;
    late MockIsarPersonDataSource mockPerson;
    late MockIsarCategoryDataSource mockCategory;
    late MockIsarSavedLocationDataSource mockSavedLoc;
    late MockIsarRelationshipDataSource mockRel;
    late MockPersonGroupLocalDataSource mockPersonGroup;
    late ExportBitacoraUseCase useCase;

    setUp(() {
      mockRepository = MockMilestoneRepository();
      mockPerson = MockIsarPersonDataSource();
      mockCategory = MockIsarCategoryDataSource();
      mockSavedLoc = MockIsarSavedLocationDataSource();
      mockRel = MockIsarRelationshipDataSource();
      mockPersonGroup = MockPersonGroupLocalDataSource();
      when(() => mockPerson.fetchAll()).thenAnswer((_) async => []);
      when(() => mockCategory.fetchAll()).thenAnswer((_) async => []);
      when(() => mockSavedLoc.fetchAll()).thenAnswer((_) async => []);
      when(() => mockRel.fetchAll()).thenAnswer((_) async => []);
      when(() => mockPersonGroup.fetchAllGroupsOrdered())
          .thenAnswer((_) async => []);
      when(() => mockPersonGroup.fetchAllLinks()).thenAnswer((_) async => []);
      when(() => mockPersonGroup.buildPersonIdToGroupIds())
          .thenAnswer((_) async => <String, List<String>>{});
      useCase = ExportBitacoraUseCase(
        mockRepository,
        mockPerson,
        mockCategory,
        mockSavedLoc,
        mockRel,
        mockPersonGroup,
      );
      registerFallbackValue(const NoParams());
    });

    test('returns Right(ExportResult) when repository succeeds', () async {
      when(() => mockRepository.getMilestones())
          .thenAnswer((_) async => Right([makeMilestone()]));

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (r) {
          expect(r.json, isNotEmpty);
          expect(r.markdown, isNotEmpty);
        },
      );
    });

    test('ExportResult json and markdown are both non-empty on success', () async {
      when(() => mockRepository.getMilestones())
          .thenAnswer((_) async => Right([makeMilestone()]));

      final result = await useCase(const NoParams());

      result.fold(
        (_) => fail('Expected Right'),
        (r) {
          expect(r.json, isNotEmpty);
          expect(r.markdown, isNotEmpty);
        },
      );
    });

    test('propagates Left(AuthFailure) when repository returns auth error', () async {
      when(() => mockRepository.getMilestones())
          .thenAnswer((_) async => const Left(AuthFailure()));

      final result = await useCase(const NoParams());

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('propagates Left(NetworkFailure) when repository returns network error', () async {
      when(() => mockRepository.getMilestones())
          .thenAnswer((_) async => const Left(NetworkFailure('timeout')));

      final result = await useCase(const NoParams());

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('ExportResult equality holds for identical content', () {
      const r1 = ExportResult(json: '{}', markdown: '# title');
      const r2 = ExportResult(json: '{}', markdown: '# title');
      expect(r1, equals(r2));
    });
  });
}
