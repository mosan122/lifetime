import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final createdAt = DateTime(2026, 4, 26);

  MediaAssetEntity makeEntity({String id = 'asset-1'}) => MediaAssetEntity(
        id: id,
        milestoneId: 'ms-1',
        cloudFileId: 'drive-abc123',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        mediaType: 'image',
        metadata: {'width': 1920, 'height': 1080},
        createdAt: createdAt,
      );

  test('two instances with same props are equal', () {
    expect(makeEntity(), equals(makeEntity()));
  });

  test('instances with different id are not equal', () {
    expect(makeEntity(id: 'asset-1'), isNot(equals(makeEntity(id: 'asset-2'))));
  });

  test('props list contains all fields', () {
    final entity = makeEntity();
    expect(entity.props, hasLength(7));
  });
}
