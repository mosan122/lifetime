import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/data/models/media_asset_model.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final tJson = {
    'id': 'asset-1',
    'milestone_id': 'ms-1',
    'cloud_file_id': 'drive-abc123',
    'thumbnail_url': 'https://example.com/thumb.jpg',
    'media_type': 'image',
    'metadata': {'width': 1920, 'height': 1080},
    'created_at': '2026-04-26T10:00:00.000Z',
  };

  test('fromJson creates correct MediaAssetModel', () {
    final model = MediaAssetModel.fromJson(tJson);

    expect(model.id, equals('asset-1'));
    expect(model.milestoneId, equals('ms-1'));
    expect(model.cloudFileId, equals('drive-abc123'));
    expect(model.thumbnailUrl, equals('https://example.com/thumb.jpg'));
    expect(model.mediaType, equals('image'));
    expect(model.metadata, equals({'width': 1920, 'height': 1080}));
    expect(model.createdAt, equals(DateTime.parse('2026-04-26T10:00:00.000Z')));
  });

  test('fromJson handles null thumbnailUrl and metadata', () {
    final json = Map<String, dynamic>.from(tJson)
      ..remove('thumbnail_url')
      ..remove('metadata');

    final model = MediaAssetModel.fromJson(json);

    expect(model.thumbnailUrl, isNull);
    expect(model.metadata, isNull);
  });

  test('is a MediaAssetEntity', () {
    expect(MediaAssetModel.fromJson(tJson), isA<MediaAssetEntity>());
  });
}
