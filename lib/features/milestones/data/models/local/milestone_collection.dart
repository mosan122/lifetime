// lib/features/milestones/data/models/local/milestone_collection.dart
import 'package:isar/isar.dart';
import '../../../../../domain/entities/milestone.dart';
import 'media_asset_embed.dart';

part 'milestone_collection.g.dart';

enum SyncStatus { synced, pending }

@Collection()
class MilestoneCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String userId;
  late String title;
  String? description;
  List<String> participants = [];
  DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(0);
  String? locationName;
  double? latitude;
  double? longitude;
  late String category;
  late bool isPublic;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? driveFileId;

  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  List<MediaAssetEmbed> media = [];

  static MilestoneCollection fromMilestone(
      Milestone milestone, SyncStatus status) {
    return MilestoneCollection()
      ..id = milestone.id
      ..userId = milestone.userId
      ..title = milestone.title
      ..description = milestone.description
      ..participants = List<String>.from(milestone.participants)
      ..eventDate = milestone.eventDate
      ..locationName = milestone.locationName
      ..latitude = milestone.latitude
      ..longitude = milestone.longitude
      ..category = milestone.category
      ..isPublic = milestone.isPublic
      ..createdAt = milestone.createdAt
      ..driveFileId = milestone.driveFileId
      ..syncStatus = status
      ..media = milestone.media.map(MediaAssetEmbed.fromEntity).toList();
  }

  Milestone toDomain() {
    return Milestone(
      id: id,
      userId: userId,
      title: title,
      description: description,
      participants: List<String>.from(participants),
      media: media.map((e) => e.toDomain()).toList(),
      eventDate: eventDate,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      category: category,
      isPublic: isPublic,
      createdAt: createdAt,
      driveFileId: driveFileId,
    );
  }
}
