import 'package:equatable/equatable.dart';

class MediaAssetEntity extends Equatable {
  final String id;
  final String milestoneId;
  final String cloudFileId;
  final String? thumbnailUrl;
  final String mediaType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const MediaAssetEntity({
    required this.id,
    required this.milestoneId,
    required this.cloudFileId,
    this.thumbnailUrl,
    required this.mediaType,
    this.metadata,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, milestoneId, cloudFileId, thumbnailUrl, mediaType, metadata, createdAt];
}
