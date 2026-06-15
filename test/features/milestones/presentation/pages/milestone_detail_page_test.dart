import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/features/milestones/presentation/pages/milestone_detail_page.dart';

void main() {
  final tDate = DateTime(2026, 4, 26);

  MilestoneModel makeMilestone({
    String id = 'ms-1',
    String title = 'Mi 30 cumpleaños',
    String? description = 'Fue un día especial.',
    String? locationName = 'Madrid',
    String? driveFileId,
    List<String> participants = const ['Ana', 'Luis'],
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
        latitude: locationName != null ? 40.4168 : null,
        longitude: locationName != null ? -3.7038 : null,
        category: 'familia',
        isPublic: false,
        createdAt: tDate,
        driveFileId: driveFileId,
      );

  // ── heroTag ───────────────────────────────────────────────────────────────

  group('MilestoneDetailPage.heroTag', () {
    test('returns the same value for the same ID (idempotent)', () {
      expect(
        MilestoneDetailPage.heroTag('ms-1'),
        equals(MilestoneDetailPage.heroTag('ms-1')),
      );
    });

    test('differs for different milestone IDs', () {
      expect(
        MilestoneDetailPage.heroTag('ms-1'),
        isNot(equals(MilestoneDetailPage.heroTag('ms-2'))),
      );
    });

    test('contains the milestone ID — source and destination tags must match', () {
      const id = 'unique-abc-123';
      expect(MilestoneDetailPage.heroTag(id), contains(id));
    });

    test('is non-empty', () {
      expect(MilestoneDetailPage.heroTag('ms-1'), isNotEmpty);
    });

    test('source card and detail page produce equal tags for the same milestone', () {
      final milestone = makeMilestone(id: 'ms-hero');
      // Simulate what _MediaCard does and what MilestoneDetailPage does.
      final cardTag = MilestoneDetailPage.heroTag(milestone.id);
      final pageTag = MilestoneDetailPage.heroTag(milestone.id);
      expect(cardTag, equals(pageTag));
    });
  });

  // ── formatForSharing ─────────────────────────────────────────────────────

  group('MilestoneDetailPage.formatForSharing', () {
    test('includes the title', () {
      final text = MilestoneDetailPage.formatForSharing(makeMilestone());
      expect(text, contains('Mi 30 cumpleaños'));
    });

    test('includes date in dd/mm/yyyy format', () {
      final text = MilestoneDetailPage.formatForSharing(makeMilestone());
      expect(text, contains('26/04/2026'));
    });

    test('includes description when available', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(description: 'Un día increíble.'),
      );
      expect(text, contains('Un día increíble.'));
    });

    test('includes location emoji and name when locationName is set', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(locationName: 'Sevilla'),
      );
      expect(text, contains('📍'));
      expect(text, contains('Sevilla'));
    });

    test('omits location line when locationName is null', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(locationName: null),
      );
      expect(text, isNot(contains('📍')));
    });

    test('is non-empty when description is null', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(description: null),
      );
      expect(text, isNotEmpty);
    });

    test('is non-empty when description is empty string', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(description: ''),
      );
      expect(text, isNotEmpty);
    });

    test('always contains LifeTime signature', () {
      final text = MilestoneDetailPage.formatForSharing(makeMilestone());
      expect(text, contains('LifeTime'));
    });

    test('handles fully null optional fields without throwing', () {
      final text = MilestoneDetailPage.formatForSharing(
        makeMilestone(description: null, locationName: null),
      );
      expect(text, isNotEmpty);
      expect(text, contains('Mi 30 cumpleaños'));
      expect(text, contains('LifeTime'));
    });

    test('includes book emoji at the start', () {
      final text = MilestoneDetailPage.formatForSharing(makeMilestone());
      expect(text, contains('📖'));
    });

    test('includes calendar emoji for date', () {
      final text = MilestoneDetailPage.formatForSharing(makeMilestone());
      expect(text, contains('📅'));
    });
  });

  // ── Argument contract ────────────────────────────────────────────────────

  group('MilestoneDetailPage — navigation argument contract', () {
    test('constructs with null accessToken (text-only milestone)', () {
      final page = MilestoneDetailPage(
        milestone: makeMilestone(),
        accessToken: null,
      );
      expect(page.milestone.id, equals('ms-1'));
      expect(page.accessToken, isNull);
    });

    test('constructs with null driveFileId (no Drive photo)', () {
      final page = MilestoneDetailPage(
        milestone: makeMilestone(driveFileId: null),
        accessToken: 'ya29.token',
      );
      expect(page.milestone.driveFileId, isNull);
    });

    test('constructs with both driveFileId and accessToken (full media)', () {
      final page = MilestoneDetailPage(
        milestone: makeMilestone(driveFileId: 'drive-file-id'),
        accessToken: 'ya29.token',
      );
      expect(page.milestone.driveFileId, equals('drive-file-id'));
      expect(page.accessToken, equals('ya29.token'));
    });

    test('constructs with fully minimal milestone (all optionals null)', () {
      final minimal = MilestoneModel(
        id: 'ms-min',
        userId: 'u-1',
        title: 'Minimal',
        description: null,
        participants: const [],
        media: const [],
        eventDate: tDate,
        locationName: null,
        latitude: null,
        longitude: null,
        category: 'general',
        isPublic: false,
        createdAt: tDate,
      );
      final page = MilestoneDetailPage(milestone: minimal);
      expect(page.milestone.id, equals('ms-min'));
      expect(page.accessToken, isNull);
    });

    test('milestone passed to page preserves all fields exactly', () {
      final original = makeMilestone(
        id: 'ms-original',
        title: 'Original Title',
        description: 'Original description.',
        participants: ['Ana', 'Luis'],
      );
      final page = MilestoneDetailPage(milestone: original);

      expect(page.milestone.id, equals('ms-original'));
      expect(page.milestone.title, equals('Original Title'));
      expect(page.milestone.description, equals('Original description.'));
      expect(page.milestone.participants, equals(['Ana', 'Luis']));
      expect(page.milestone.category, equals('familia'));
      expect(page.milestone.eventDate, equals(tDate));
    });

    test('heroTag derived from milestone.id stays consistent after construction', () {
      final milestone = makeMilestone(id: 'ms-nav');
      final page = MilestoneDetailPage(milestone: milestone);

      // Same ID → same tag, every time
      expect(
        MilestoneDetailPage.heroTag(page.milestone.id),
        equals(MilestoneDetailPage.heroTag(milestone.id)),
      );
    });
  });
}
