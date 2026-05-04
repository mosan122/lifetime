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
  /// Índice en [mediaItems] del medio que se muestra en el timeline y en el encabezado del detalle.
  final int galleryCoverIndex;
  final DateTime eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  /// Local category reference (Isar `CategoryCollection.id`).
  /// 1 is reserved for the seeded "General" category.
  final int categoryId;
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
    this.galleryCoverIndex = 0,
    required this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.categoryId = 1,
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
        galleryCoverIndex,
        eventDate,
        locationName,
        latitude,
        longitude,
        categoryId,
        isPublic,
        createdAt,
        driveFileId,
      ];
}
