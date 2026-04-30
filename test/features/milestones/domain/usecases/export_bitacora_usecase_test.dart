import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/usecases/usecase.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/repositories/milestone_repository.dart';
import 'package:lifetime/features/milestones/domain/usecases/export_bitacora_usecase.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

void main() {
  final tDate = DateTime(2026, 4, 26);

  MilestoneModel makeMilestone({
    String id = 'ms-1',
    String title = 'Mi 30 cumpleaños',
    String? description = 'Fue un día especial.',
    String? locationName = 'Madrid',
    double? latitude = 40.4168,
    double? longitude = -3.7038,
    List<String> participants = const ['Ana', 'Luis'],
    String? driveFileId,
  }) =>
      MilestoneModel(
        id: id,
        userId: 'user-1',
        title: title,
        description: description,
        participants: participants,
        media: const [],
        eventDate: tDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: 'familia',
        isPublic: false,
        createdAt: tDate,
        driveFileId: driveFileId,
      );

  // ── toJson ───────────────────────────────────────────────────────────────────

  group('ExportBitacoraUseCase.toJson', () {
    test('produces valid JSON that does not throw on decode', () {
      expect(
        () => jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])),
        returnsNormally,
      );
    });

    test('contains version 1.0', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([])) as Map;
      expect(data['version'], equals('1.0'));
    });

    test('contains exported_at field', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([])) as Map;
      expect(data['exported_at'], isNotNull);
    });

    test('total matches milestone count', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson(
        [makeMilestone(), makeMilestone(id: 'ms-2')],
      )) as Map;
      expect(data['total'], equals(2));
    });

    test('empty list produces total 0 and empty array', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([])) as Map;
      expect(data['total'], equals(0));
      expect((data['milestones'] as List), isEmpty);
    });

    test('title is present in milestone entry', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      expect((data['milestones'] as List)[0]['title'], equals('Mi 30 cumpleaños'));
    });

    test('description (narrative) is present in milestone entry', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      expect((data['milestones'] as List)[0]['description'], equals('Fue un día especial.'));
    });

    test('event_date is formatted as YYYY-MM-DD', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      expect((data['milestones'] as List)[0]['event_date'], equals('2026-04-26'));
    });

    test('location contains latitude and longitude when coords are present', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      final loc = (data['milestones'] as List)[0]['location'] as Map;
      expect(loc['latitude'], equals(40.4168));
      expect(loc['longitude'], equals(-3.7038));
    });

    test('location contains name when locationName is set', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      final loc = (data['milestones'] as List)[0]['location'] as Map;
      expect(loc['name'], equals('Madrid'));
    });

    test('location is null when latitude and longitude are null', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([
        makeMilestone(latitude: null, longitude: null, locationName: null),
      ])) as Map;
      expect((data['milestones'] as List)[0]['location'], isNull);
    });

    test('participants list is included', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson([makeMilestone()])) as Map;
      expect(
        (data['milestones'] as List)[0]['participants'],
        equals(['Ana', 'Luis']),
      );
    });

    test('drive_file_id is included when present', () {
      final data = jsonDecode(ExportBitacoraUseCase.toJson(
        [makeMilestone(driveFileId: 'drive-abc')],
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
        makeMilestone(participants: []),
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
    late ExportBitacoraUseCase useCase;

    setUp(() {
      mockRepository = MockMilestoneRepository();
      useCase = ExportBitacoraUseCase(mockRepository);
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
