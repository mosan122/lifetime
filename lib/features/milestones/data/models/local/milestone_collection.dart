// lib/features/milestones/data/models/local/milestone_collection.dart
import 'package:isar/isar.dart';
import '../../../../../domain/entities/milestone.dart';
import 'media_asset_embed.dart';
import 'media_item_embed.dart';

part 'milestone_collection.g.dart';

// 
enum SyncStatus { synced, pending }

@embedded
class MilestoneLocationDataEmbed {
  String? name;
  String? city;
  String? country;
  double? latitude;
  double? longitude;
}

@Collection()
class MilestoneCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String userId;
  late String title;
  String? description;
  // Centralized people: store Person IDs here (was previously plain names).
  List<String> participants = [];
  /// Subset of [participants] marked as protagonists.
  List<String> protagonists = [];
  List<String> tags = [];
  DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(0);

  /// Link to a saved favorite location (Isar `SavedLocationCollection.isarId`).
  int? savedLocationId;
  /// New location structure (preferred).
  MilestoneLocationDataEmbed? location;

  /// Legacy fields (kept for backward compatibility with older local DB data).
  String? locationName;
  double? latitude;
  double? longitude;
  String? categoryId;
  late bool isPublic;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? driveFileId;
  String? driveFolderId;

  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  List<MediaAssetEmbed> media = [];
  List<MediaItemEmbed> mediaItems = [];
  int galleryCoverIndex = 0;

  static MilestoneCollection fromMilestone(
      Milestone milestone, SyncStatus status) {
    return MilestoneCollection()
      ..id = milestone.id
      ..userId = milestone.userId
      ..title = milestone.title
      ..description = milestone.description
      ..participants = List<String>.from(milestone.participantIds)
      ..protagonists = List<String>.from(milestone.protagonistIds)
      ..tags = List<String>.from(milestone.tags)
      ..eventDate = milestone.eventDate
      ..savedLocationId = milestone.savedLocationId
      ..location = (() {
        final name = milestone.locationName;
        final lat = milestone.latitude;
        final lon = milestone.longitude;
        if ((name == null || name.trim().isEmpty) && lat == null && lon == null) {
          return null;
        }
        return MilestoneLocationDataEmbed()
          ..name = name
          ..city = milestone.locationCity
          ..country = milestone.locationCountry
          ..latitude = lat
          ..longitude = lon;
      })()
      ..locationName = milestone.locationName
      ..latitude = milestone.latitude
      ..longitude = milestone.longitude
      ..categoryId = milestone.categoryId
      ..isPublic = milestone.isPublic
      ..createdAt = milestone.createdAt
      ..driveFileId = milestone.driveFileId
      ..syncStatus = status
      ..media = milestone.media.map(MediaAssetEmbed.fromEntity).toList()
      ..mediaItems = milestone.mediaItems.map(MediaItemEmbed.fromDomain).toList()
      ..galleryCoverIndex = milestone.galleryCoverIndex;
  }

  Milestone toDomain() {
    final loc = location;
    final legacyName = locationName;
    final name = (loc?.name?.trim().isNotEmpty ?? false)
        ? loc!.name!.trim()
        : (legacyName?.trim().isNotEmpty ?? false)
            ? legacyName!.trim()
            : null;
    final lat = loc?.latitude ?? latitude;
    final lon = loc?.longitude ?? longitude;

    return Milestone(
      id: id,
      userId: userId,
      title: title,
      description: description,
      participants: const [],
      participantIds: List<String>.from(participants),
      protagonistIds: List<String>.from(protagonists),
      tags: List<String>.from(tags),
      media: media.map((e) => e.toDomain()).toList(),
      mediaItems: mediaItems.map((e) => e.toDomain()).toList(),
      galleryCoverIndex: galleryCoverIndex,
      eventDate: eventDate,
      savedLocationId: savedLocationId,
      locationName: name,
      locationCity: (loc?.city?.trim().isNotEmpty ?? false) ? loc!.city!.trim() : null,
      locationCountry:
          (loc?.country?.trim().isNotEmpty ?? false) ? loc!.country!.trim() : null,
      latitude: lat,
      longitude: lon,
      categoryId: categoryId,
      isPublic: isPublic,
      createdAt: createdAt,
      driveFileId: driveFileId,
    );
  }
}
