import '../../domain/entities/milestone.dart';
import 'media_asset_model.dart';

class MilestoneModel extends Milestone {
  const MilestoneModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.participants = const [],
    super.participantIds = const [],
    super.tags = const [],
    super.media = const [],
    super.mediaItems = const [],
    super.galleryCoverIndex = 0,
    required super.eventDate,
    super.locationName,
    super.locationCity,
    super.locationCountry,
    super.latitude,
    super.longitude,
    super.categoryId,
    super.isPublic = false,
    required super.createdAt,
    super.driveFileId,
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
      participantIds:
          List<String>.from(json['participant_ids'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      media: (json['media_assets'] as List? ?? [])
          .map((e) => MediaAssetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      galleryCoverIndex:
          (json['gallery_cover_index'] as num?)?.toInt() ?? 0,
      eventDate: DateTime.parse(json['event_date'] as String),
      locationName: json['location_name'] as String?,
      // Backend does not persist these (yet). They remain local-only.
      locationCity: null,
      locationCountry: null,
      latitude: latitude,
      longitude: longitude,
      categoryId: _categoryIdFromRemote(json['category'] as String?),
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      driveFileId: json['drive_file_id'] as String?,
    );
  }

  static String? _categoryIdFromRemote(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;

    // If backend already stores ids (e.g. "familia"), keep it.
    const known = <String>{
      'familia',
      'amigos',
      'amor',
      'mascotas',
      'viajes',
      'naturaleza',
      'ocio',
      'trabajo',
      'formacion',
      'finanzas',
      'salud',
      'deporte',
      'hogar',
      'gastronomia',
      'diy',
      'nacimiento',
      'defuncion',
      'otros',
    };
    if (known.contains(v)) return v;

    // Legacy mapping (older strings).
    if (v == 'general') return 'otros';
    if (v == 'cumpleaños' || v == 'cumpleanos') return 'familia';
    if (v == 'boda') return 'amor';
    if (v == 'especial') return 'otros';
    return 'otros';
  }

  // Método estático para construir el payload de inserción.
  // No incluye 'id', 'user_id' ni 'created_at' — los genera Supabase.
  static Map<String, dynamic> toInsertMap({
    required String title,
    required String? description,
    required List<String> participants,
    List<String> participantIds = const [],
    List<String> tags = const [],
    required DateTime eventDate,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required String categoryId,
    required bool isPublic,
    String? driveFileId,
  }) {
    final map = <String, dynamic>{
      'title': title,
      'participants': participants,
      'participant_ids': participantIds,
      'tags': tags,
      'event_date': eventDate.toIso8601String(),
      'category': categoryId,
      'is_public': isPublic,
    };
    if (description != null) map['description'] = description;
    if (locationName != null) map['location_name'] = locationName;
    if (latitude != null && longitude != null) {
      map['location_coords'] = 'POINT($longitude $latitude)';
    }
    if (driveFileId != null) map['drive_file_id'] = driveFileId;
    return map;
  }

  static Map<String, dynamic> toUpdateMap({
    String? title,
    String? categoryId,
    required String description,
    DateTime? eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String>? participantIds,
    List<String>? tags,
  }) {
    final map = <String, dynamic>{'description': description};
    if (title != null) map['title'] = title;
    if (categoryId != null) map['category'] = categoryId;
    if (eventDate != null) map['event_date'] = eventDate.toIso8601String();
    if (locationName != null) map['location_name'] = locationName;
    if (latitude != null && longitude != null) {
      map['location_coords'] = 'POINT($longitude $latitude)';
    }
    if (participantIds != null) map['participant_ids'] = participantIds;
    if (tags != null) map['tags'] = tags;
    return map;
  }
}
