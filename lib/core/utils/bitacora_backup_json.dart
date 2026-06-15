import 'dart:convert';

import '../../domain/entities/media_item.dart';
import '../../domain/entities/milestone.dart';
import 'milestone_title_utils.dart';

/// Datos adicionales para exportación v3 (personas, categorías personalizadas, etc.).
/// Listas de mapas con claves snake_case estables en el JSON.
/// En `people`, además de los campos escalares: opcional `group_ids` (lista de ids de grupo)
/// y `face_portrait_base64` (JPEG en base64) para copias portables entre dispositivos.
class BitacoraExportBundles {
  const BitacoraExportBundles({
    this.people = const [],
    this.customCategories = const [],
    this.savedLocations = const [],
    this.groups = const [],
    this.personGroupLinks = const [],
    this.relationships = const [],
  });

  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> customCategories;
  final List<Map<String, dynamic>> savedLocations;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> personGroupLinks;
  final List<Map<String, dynamic>> relationships;

  bool get isEmpty =>
      people.isEmpty &&
      customCategories.isEmpty &&
      savedLocations.isEmpty &&
      groups.isEmpty &&
      personGroupLinks.isEmpty &&
      relationships.isEmpty;
}

/// Resultado del análisis de un JSON de copia (importación).
class BitacoraImportPreview {
  const BitacoraImportPreview({
    required this.isLegacyMilestonesOnly,
    required this.milestoneMaps,
    required this.peopleMaps,
    required this.customCategoriesMaps,
    required this.savedLocationsMaps,
    required this.groupsMaps,
    required this.personGroupLinksMaps,
    required this.relationshipsMaps,
  });

  final bool isLegacyMilestonesOnly;
  final List<Map<String, dynamic>> milestoneMaps;
  final List<Map<String, dynamic>> peopleMaps;
  final List<Map<String, dynamic>> customCategoriesMaps;
  final List<Map<String, dynamic>> savedLocationsMaps;
  final List<Map<String, dynamic>> groupsMaps;
  final List<Map<String, dynamic>> personGroupLinksMaps;
  final List<Map<String, dynamic>> relationshipsMaps;
}

/// Codificación / decodificación del JSON de copia de seguridad de LifeTime.
abstract final class BitacoraBackupJson {
  static const String appKey = 'LifeTime';
  static const String currentVersion = '3.0';
  static const String legacyVersion = '2.0';
  static const String schemaFull = 'bitacora';
  static const String schemaMilestonesOnly = 'bitacora_milestones';

  /// Export v3 con hitos y [extras]. Si [extras] está vacío, solo se serializan hitos
  /// (misma información que antes) pero con versión 3.0 y schema [schemaFull].
  static String encode(
    List<Milestone> milestones, [
    BitacoraExportBundles extras = const BitacoraExportBundles(),
  ]) {
    final now = DateTime.now().toUtc();

    final refByIsarId = <int, String>{
      for (final row in extras.savedLocations)
        if (row['source_isar_id'] is int)
          row['source_isar_id'] as int: (row['ref'] as String?) ?? '',
    };

    final milestoneMaps = milestones
        .map((m) => _milestoneToMap(m, refByIsarId: refByIsarId))
        .toList();

    final data = <String, dynamic>{
      'app': appKey,
      'exported_at': now.toIso8601String(),
      'version': currentVersion,
      'schema': schemaFull,
      'total': milestones.length,
      'milestones': milestoneMaps,
      'people': extras.people,
      'custom_categories': extras.customCategories,
      'saved_locations': extras.savedLocations,
      'groups': extras.groups,
      'person_group_links': extras.personGroupLinks,
      'relationships': extras.relationships,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Map<String, dynamic> _milestoneToMap(
    Milestone m, {
    required Map<int, String> refByIsarId,
  }) {
    final d = m.eventDate;
    final loc = (m.latitude != null && m.longitude != null) ||
            (m.locationName != null && m.locationName!.trim().isNotEmpty)
        ? <String, dynamic>{
            'name': m.locationName,
            'city': m.locationCity,
            'country': m.locationCountry,
            'latitude': m.latitude,
            'longitude': m.longitude,
          }
        : null;

    final sid = m.savedLocationId;
    final String? ref =
        (sid != null && refByIsarId.containsKey(sid)) ? refByIsarId[sid] : null;

    return {
      'id': m.id,
      'user_id': m.userId,
      'title': m.title,
      'description': m.description,
      'event_date':
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'category_id': m.categoryId,
      'location': loc,
      'participant_ids': List<String>.from(m.participantIds),
      'protagonist_ids': List<String>.from(m.protagonistIds),
      'tags': List<String>.from(m.tags),
      'gallery_cover_index': m.galleryCoverIndex,
      if (ref != null && ref.isNotEmpty) 'saved_location_ref': ref,
      'is_public': m.isPublic,
      'created_at': m.createdAt.toUtc().toIso8601String(),
      'drive_file_id': m.driveFileId,
      'media_items': m.mediaItems.map(_mediaItemToMap).toList(),
    };
  }

  static Map<String, dynamic> _mediaItemToMap(MediaItem it) {
    return {
      'local_path': it.localPath,
      'thumbnail_path': it.thumbnailPath,
      'media_type': it.mediaType.name,
      'drive_file_id': it.driveFileId,
      'is_synced': it.isSynced,
      'is_deleted': it.isDeleted,
    };
  }

  /// Devuelve el número de hitos reconocidos en el JSON (sin escribir en BD).
  static int countMilestones(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return 0;
      final list = decoded['milestones'];
      if (list is! List) return 0;
      return list.whereType<Map>().length;
    } catch (_) {
      return 0;
    }
  }

  /// Export antiguo (solo lista de hitos, sin secciones v3): JSON con schema
  /// [schemaMilestonesOnly] y versión 2.0. Solo para pruebas / compatibilidad.
  static String encodeLegacyMilestonesOnly(List<Milestone> milestones) {
    final now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      'app': appKey,
      'exported_at': now.toIso8601String(),
      'version': legacyVersion,
      'schema': schemaMilestonesOnly,
      'total': milestones.length,
      'milestones': milestones.map((m) => _legacyMilestoneToMap(m)).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Map<String, dynamic> _legacyMilestoneToMap(Milestone m) {
    final map = _milestoneToMap(m, refByIsarId: const {});
    map['saved_location_id'] = m.savedLocationId;
    return map;
  }

  static bool isLegacyMilestonesOnlyMap(Map<String, dynamic> decoded) {
    final schema = (decoded['schema'] as String?)?.trim();
    final ver = (decoded['version'] as String?)?.trim();
    if (schema == schemaMilestonesOnly) return true;
    if (ver == legacyVersion || ver == '1.0') return true;
    return false;
  }

  /// Analiza el JSON para importación (hitos + secciones opcionales).
  static BitacoraImportPreview parseImportPreview(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El archivo no es un objeto JSON.');
    }
    final app = (decoded['app'] as String?)?.trim();
    if (app != null && app.isNotEmpty && app != appKey) {
      throw FormatException('App desconocida en export: $app');
    }
    final list = decoded['milestones'];
    if (list is! List) {
      throw const FormatException('Falta la lista milestones.');
    }
    final milestoneMaps = <Map<String, dynamic>>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      milestoneMaps.add(Map<String, dynamic>.from(raw));
    }

    final legacy = isLegacyMilestonesOnlyMap(decoded);
    if (legacy) {
      return BitacoraImportPreview(
        isLegacyMilestonesOnly: true,
        milestoneMaps: milestoneMaps,
        peopleMaps: const [],
        customCategoriesMaps: const [],
        savedLocationsMaps: const [],
        groupsMaps: const [],
        personGroupLinksMaps: const [],
        relationshipsMaps: const [],
      );
    }

    List<Map<String, dynamic>> asMapList(String key) {
      final v = decoded[key];
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return BitacoraImportPreview(
      isLegacyMilestonesOnly: false,
      milestoneMaps: milestoneMaps,
      peopleMaps: asMapList('people'),
      customCategoriesMaps: asMapList('custom_categories'),
      savedLocationsMaps: asMapList('saved_locations'),
      groupsMaps: asMapList('groups'),
      personGroupLinksMaps: asMapList('person_group_links'),
      relationshipsMaps: asMapList('relationships'),
    );
  }

  /// Convierte hitos del JSON a entidades [Milestone].
  static List<Milestone> decodeMilestones(
    String json, {
    required String userId,
    bool forceUserId = true,
    Map<String, int>? savedLocationRefToIsarId,
  }) {
    final preview = parseImportPreview(json);
    return decodeMilestonesFromPreview(
      preview,
      userId: userId,
      forceUserId: forceUserId,
      savedLocationRefToIsarId: savedLocationRefToIsarId,
    );
  }

  static List<Milestone> decodeMilestonesFromPreview(
    BitacoraImportPreview preview, {
    required String userId,
    bool forceUserId = true,
    Map<String, int>? savedLocationRefToIsarId,
  }) {
    return preview.milestoneMaps
        .map(
          (m) => _milestoneFromMap(
            m,
            userId,
            forceUserId: forceUserId,
            savedLocationRefToIsarId: savedLocationRefToIsarId,
          ),
        )
        .toList();
  }

  static Milestone _milestoneFromMap(
    Map<String, dynamic> m,
    String userId, {
    required bool forceUserId,
    Map<String, int>? savedLocationRefToIsarId,
  }) {
    final id = (m['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Hito sin id válido.');
    }

    final uid = (m['user_id'] as String?)?.trim();
    final effectiveUser =
        forceUserId ? userId : ((uid != null && uid.isNotEmpty) ? uid : userId);

    final titleRaw = (m['title'] as String?)?.trim() ?? '';
    final desc = m['description'] as String?;

    final eventDate = _parseEventDate(m['event_date'] as String?);
    final createdAt = _parseCreatedAt(m['created_at'] as String?, eventDate);

    final participantIds = _stringList(
      m['participant_ids'] ?? m['participants'],
    );
    final protagonistIds = _stringList(m['protagonist_ids']);
    final tags = _stringList(m['tags']);

    final loc = m['location'];
    String? locName;
    String? locCity;
    String? locCountry;
    double? lat;
    double? lon;
    if (loc is Map) {
      final lm = Map<String, dynamic>.from(loc);
      locName = lm['name'] as String?;
      locCity = lm['city'] as String?;
      locCountry = lm['country'] as String?;
      lat = (lm['latitude'] as num?)?.toDouble();
      lon = (lm['longitude'] as num?)?.toDouble();
    }

    lat ??= (m['latitude'] as num?)?.toDouble();
    lon ??= (m['longitude'] as num?)?.toDouble();
    locName ??= m['location_name'] as String?;

    final categoryId = (m['category_id'] as String?)?.trim().toLowerCase();
    final galleryCover = (m['gallery_cover_index'] as num?)?.toInt() ?? 0;

    int? savedLocationId;
    final refRaw = (m['saved_location_ref'] as String?)?.trim();
    if (refRaw != null &&
        refRaw.isNotEmpty &&
        savedLocationRefToIsarId != null) {
      savedLocationId = savedLocationRefToIsarId[refRaw];
    }
    if (savedLocationId == null) {
      final rawSaved = m['saved_location_id'];
      if (rawSaved is int) {
        savedLocationId = rawSaved;
      } else if (rawSaved is num) {
        savedLocationId = rawSaved.toInt();
      }
    }

    final isPublic = m['is_public'] as bool? ?? false;
    final driveFileId = m['drive_file_id'] as String?;

    final mediaItems = _parseMediaItems(m['media_items']);

    final title = titleRaw.isNotEmpty
        ? titleRaw
        : milestoneFallbackTitleFromDescription(desc ?? '');

    return Milestone(
      id: id,
      userId: effectiveUser,
      title: title,
      description: desc,
      participants: const [],
      participantIds: participantIds,
      protagonistIds: protagonistIds
          .where((p) => participantIds.contains(p))
          .toList(),
      tags: tags,
      media: const [],
      mediaItems: mediaItems,
      galleryCoverIndex: galleryCover,
      eventDate: eventDate,
      savedLocationId: savedLocationId,
      locationName: locName,
      locationCity: locCity,
      locationCountry: locCountry,
      latitude: lat,
      longitude: lon,
      categoryId: (categoryId != null && categoryId.isNotEmpty)
          ? categoryId
          : 'otros',
      isPublic: isPublic,
      createdAt: createdAt,
      driveFileId: driveFileId,
      isSynced: m['is_synced'] as bool? ?? false,
    );
  }

  static DateTime _parseEventDate(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return DateTime.now();
    final parts = v.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final mo = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    return DateTime.tryParse(v) ?? DateTime.now();
  }

  static DateTime _parseCreatedAt(String? raw, DateTime fallback) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return fallback;
    return DateTime.tryParse(v)?.toLocal() ?? fallback;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => '$e'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<MediaItem> _parseMediaItems(Object? raw) {
    if (raw is! List) return const [];
    final out = <MediaItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final mm = Map<String, dynamic>.from(e);
      final path = (mm['local_path'] as String?)?.trim() ?? '';
      if (path.isEmpty) continue;
      final thumb = (mm['thumbnail_path'] as String?)?.trim() ?? path;
      final typeName = (mm['media_type'] as String?)?.trim().toLowerCase();
      final type = typeName == 'video' ? MediaType.video : MediaType.image;
      out.add(
        MediaItem(
          localPath: path,
          thumbnailPath: thumb,
          mediaType: type,
          driveFileId: mm['drive_file_id'] as String?,
          isSynced: mm['is_synced'] as bool? ?? false,
          isDeleted: mm['is_deleted'] as bool? ?? false,
        ),
      );
    }
    return out;
  }
}
