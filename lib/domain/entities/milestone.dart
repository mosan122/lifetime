import 'package:equatable/equatable.dart';
import 'media_asset_entity.dart';

class Milestone extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> participants;
  final List<MediaAssetEntity> media;
  final DateTime eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String category;
  final bool isPublic;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.participants = const [],
    this.media = const [],
    required this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.category = 'general',
    this.isPublic = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        participants,
        media,
        eventDate,
        locationName,
        latitude,
        longitude,
        category,
        isPublic,
        createdAt,
      ];
}
