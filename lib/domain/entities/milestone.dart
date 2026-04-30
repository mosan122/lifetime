import 'package:equatable/equatable.dart';
import 'media_item.dart';
import 'media_asset_entity.dart';

class Milestone extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> participants;
  final List<String> participantIds;
  final List<String> tags;
  final List<MediaAssetEntity> media;
  final List<MediaItem> mediaItems;
  final DateTime eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String category;
  final bool isPublic;
  final DateTime createdAt;
  final String? driveFileId;

  const Milestone({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.participants = const [],
    this.participantIds = const [],
    this.tags = const [],
    this.media = const [],
    this.mediaItems = const [],
    required this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.category = 'general',
    this.isPublic = false,
    required this.createdAt,
    this.driveFileId,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        participants,
        participantIds,
        tags,
        media,
        mediaItems,
        eventDate,
        locationName,
        latitude,
        longitude,
        category,
        isPublic,
        createdAt,
        driveFileId,
      ];
}
