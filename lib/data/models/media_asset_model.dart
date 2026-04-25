import '../../domain/entities/media_asset_entity.dart';

class MediaAssetModel extends MediaAssetEntity {
  const MediaAssetModel({
    required super.id,
    required super.milestoneId,
    required super.cloudFileId,
    super.thumbnailUrl,
    required super.mediaType,
    super.metadata,
    required super.createdAt,
  });

  factory MediaAssetModel.fromJson(Map<String, dynamic> json) {
    return MediaAssetModel(
      id: json['id'] as String,
      milestoneId: json['milestone_id'] as String,
      cloudFileId: json['cloud_file_id'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      mediaType: json['media_type'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
