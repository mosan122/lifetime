// lib/features/milestones/data/models/local/media_asset_embed.dart
import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../../../domain/entities/media_asset_entity.dart';

part 'media_asset_embed.g.dart';

@Embedded()
class MediaAssetEmbed {
  String id = '';
  String milestoneId = '';
  String cloudFileId = '';
  String? thumbnailUrl;
  String mediaType = '';
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? metadataJson;

  static MediaAssetEmbed fromEntity(MediaAssetEntity entity) {
    return MediaAssetEmbed()
      ..id = entity.id
      ..milestoneId = entity.milestoneId
      ..cloudFileId = entity.cloudFileId
      ..thumbnailUrl = entity.thumbnailUrl
      ..mediaType = entity.mediaType
      ..createdAt = entity.createdAt
      ..metadataJson =
          entity.metadata != null ? jsonEncode(entity.metadata) : null;
  }

  MediaAssetEntity toDomain() {
    return MediaAssetEntity(
      id: id,
      milestoneId: milestoneId,
      cloudFileId: cloudFileId,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      metadata: metadataJson != null
          ? jsonDecode(metadataJson!) as Map<String, dynamic>
          : null,
      createdAt: createdAt,
    );
  }
}
