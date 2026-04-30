import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/domain/entities/milestone.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final eventDate = DateTime(2026, 4, 26);
  final createdAt = DateTime(2026, 4, 26, 10, 0);
  final tMedia = MediaAssetEntity(
    id: 'asset-1',
    milestoneId: 'ms-1',
    cloudFileId: 'drive-abc',
    mediaType: 'image',
    createdAt: createdAt,
  );

  Milestone makeMilestone({String id = 'ms-1'}) => Milestone(
        id: id,
        userId: 'user-1',
        title: 'Mi 30 cumpleaños',
        description: 'Fue un día especial.',
        participants: const ['Ana', 'Carlos'],
        media: [tMedia],
        eventDate: eventDate,
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'familia',
        isPublic: false,
        createdAt: createdAt,
      );

  test('two instances with same props are equal', () {
    expect(makeMilestone(), equals(makeMilestone()));
  });

  test('instances with different id are not equal', () {
    expect(makeMilestone(id: 'ms-1'), isNot(equals(makeMilestone(id: 'ms-2'))));
  });

  test('default category is general', () {
    final m = Milestone(
      id: 'ms-1',
      userId: 'user-1',
      title: 'Test',
      eventDate: eventDate,
      createdAt: createdAt,
    );
    expect(m.category, equals('general'));
  });

  test('default isPublic is false', () {
    final m = Milestone(
      id: 'ms-1',
      userId: 'user-1',
      title: 'Test',
      eventDate: eventDate,
      createdAt: createdAt,
    );
    expect(m.isPublic, isFalse);
  });

  test('props list contains all 17 fields', () {
    expect(makeMilestone().props, hasLength(17));
  });
}
