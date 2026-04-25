import '../../domain/entities/milestone.dart';
import 'media_asset_model.dart';

class MilestoneModel extends Milestone {
  const MilestoneModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.participants = const [],
    super.media = const [],
    required super.eventDate,
    super.locationName,
    super.latitude,
    super.longitude,
    super.category = 'general',
    super.isPublic = false,
    required super.createdAt,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    double? latitude;
    double? longitude;

    final coords = json['location_coords'];
    if (coords is Map) {
      // PostgREST devuelve GEOGRAPHY como GeoJSON: {"type":"Point","coordinates":[lng, lat]}
      final rawCoords = coords['coordinates'];
      if (rawCoords is List && rawCoords.length >= 2) {
        longitude = (rawCoords[0] as num).toDouble();
        latitude = (rawCoords[1] as num).toDouble();
      }
    }

    return MilestoneModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      participants: List<String>.from(json['participants'] as List? ?? []),
      media: (json['media_assets'] as List? ?? [])
          .map((e) => MediaAssetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventDate: DateTime.parse(json['event_date'] as String),
      locationName: json['location_name'] as String?,
      latitude: latitude,
      longitude: longitude,
      category: json['category'] as String? ?? 'general',
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Método estático para construir el payload de inserción.
  // No incluye 'id', 'user_id' ni 'created_at' — los genera Supabase.
  static Map<String, dynamic> toInsertMap({
    required String title,
    required String? description,
    required List<String> participants,
    required DateTime eventDate,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required String category,
    required bool isPublic,
  }) {
    final map = <String, dynamic>{
      'title': title,
      'participants': participants,
      'event_date': eventDate.toIso8601String(),
      'category': category,
      'is_public': isPublic,
    };
    if (description != null) map['description'] = description;
    if (locationName != null) map['location_name'] = locationName;
    if (latitude != null && longitude != null) {
      map['location_coords'] = 'POINT($longitude $latitude)';
    }
    return map;
  }
}
