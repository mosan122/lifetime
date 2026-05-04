// lib/features/milestones/data/models/local/milestone_collection.dart
import 'package:isar/isar.dart';
import '../../../../../domain/entities/milestone.dart';
import 'media_asset_embed.dart';
import 'media_item_embed.dart';

part 'milestone_collection.g.dart';

// 
enum SyncStatus { synced, pending }

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
  List<String> tags = [];
  DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(0);
  String? locationName;
  double? latitude;
  double? longitude;
  int categoryId = 1;
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
      ..tags = List<String>.from(milestone.tags)
      ..eventDate = milestone.eventDate
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
    return Milestone(
      id: id,
      userId: userId,
      title: title,
      description: description,
      participants: const [],
      participantIds: List<String>.from(participants),
      tags: List<String>.from(tags),
      media: media.map((e) => e.toDomain()).toList(),
      mediaItems: mediaItems.map((e) => e.toDomain()).toList(),
      galleryCoverIndex: galleryCoverIndex,
      eventDate: eventDate,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      categoryId: categoryId,
      isPublic: isPublic,
      createdAt: createdAt,
      driveFileId: driveFileId,
    );
  }
}
