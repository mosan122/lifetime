import 'dart:developer' as developer;

import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/milestone_category_seeds.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../../data/datasources/milestone_remote_datasource.dart';
import '../../../../data/models/milestone_model.dart';
import '../../../milestones/data/datasources/isar_category_datasource.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/datasources/isar_relationship_datasource.dart';
import '../../../milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/category_collection.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/milestone_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/data/models/local/relationship_collection.dart';
import '../../../milestones/data/models/local/saved_location_collection.dart';

/// Descarga datos premium de Supabase → Isar (restauración en dispositivo nuevo).
class PremiumCloudPull {
  PremiumCloudPull(
    this._supabase,
    this._isar,
    this._milestoneRemote,
    this._milestoneDs,
    this._personDs,
    this._relationshipDs,
    this._personGroupDs,
    this._categoryDs,
    this._savedLocationDs,
  );

  final SupabaseClient _supabase;
  final Isar _isar;
  final MilestoneRemoteDataSource _milestoneRemote;
  final IsarMilestoneDataSource _milestoneDs;
  final IsarPersonDataSource _personDs;
  final IsarRelationshipDataSource _relationshipDs;
  final PersonGroupLocalDataSource _personGroupDs;
  final IsarCategoryDataSource _categoryDs;
  final IsarSavedLocationDataSource _savedLocationDs;

  static const _logName = 'PremiumCloudPull';

  static Set<String> get _builtInCategoryIds => {
        for (final s in kMilestoneCategorySeeds) s.id.toLowerCase(),
      };

  Future<PremiumCloudPullResult> pullAll(String userId) async {
    var people = 0;
    var relationships = 0;
    var milestones = 0;
    var groups = 0;
    var groupLinks = 0;
    var categories = 0;
    var locations = 0;
    final errors = <String>[];

    try {
      people = await _pullPeople(userId);
    } catch (e, st) {
      errors.add('Personas: $e');
      developer.log('pull people', name: _logName, error: e, stackTrace: st);
    }

    try {
      relationships = await _pullRelationships(userId);
    } catch (e, st) {
      errors.add('Relaciones: $e');
      developer.log('pull relationships', name: _logName, error: e, stackTrace: st);
    }

    try {
      final g = await _pullGroups(userId);
      groups = g.$1;
      groupLinks = g.$2;
    } catch (e, st) {
      errors.add('Grupos o enlaces persona–grupo: $e');
      developer.log('pull groups', name: _logName, error: e, stackTrace: st);
    }

    try {
      categories = await _pullCustomCategories(userId);
    } catch (e, st) {
      errors.add('Categorías: $e');
      developer.log('pull categories', name: _logName, error: e, stackTrace: st);
    }

    try {
      locations = await _pullSavedLocations(userId);
    } catch (e, st) {
      errors.add('Lugares: $e');
      developer.log('pull locations', name: _logName, error: e, stackTrace: st);
    }

    try {
      milestones = await _pullMilestones(userId);
    } catch (e, st) {
      errors.add('Hitos: $e');
      developer.log('pull milestones', name: _logName, error: e, stackTrace: st);
    }

    return PremiumCloudPullResult(
      people: people,
      relationships: relationships,
      milestones: milestones,
      groups: groups,
      groupLinks: groupLinks,
      categories: categories,
      locations: locations,
      errors: errors,
    );
  }

  Future<int> _pullPeople(String userId) async {
    final rows = await _supabase
        .from('contact_people')
        .select()
        .eq('user_id', userId);
    var n = 0;
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final clientId = (map['client_id'] as String?)?.trim();
      if (clientId == null || clientId.isEmpty) continue;

      final existing = await _personDs.fetchByIdIncludingDeleted(clientId);
      if (existing != null) {
        if (existing.isDeleted) continue;
        if (!existing.isSynced) continue;
      }

      final row = PersonCollection()
        ..id = clientId
        ..name = (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : clientId
        ..firstName = (map['first_name'] as String?)?.trim()
        ..lastName = (map['last_name'] as String?)?.trim()
        ..birthDate = _parseDate(map['birth_date'])
        ..group = ''
        ..notes = (map['notes'] as String?) ?? ''
        ..linkedUserEmail = (map['linked_user_email'] as String?)?.trim()
        ..linkedUserId = (map['linked_user_id'] as String?)?.trim()
        ..driveFaceFileId = (map['drive_face_file_id'] as String?)?.trim()
        ..supabaseId = map['id'] as String?
        ..isSynced = true
        ..isDeleted = false;

      if (existing != null) {
        row.isarId = existing.isarId;
        row.faceImagePath = existing.faceImagePath;
        if (row.driveFaceFileId == null || row.driveFaceFileId!.isEmpty) {
          row.driveFaceFileId = existing.driveFaceFileId;
        }
      }

      await _personDs.upsert(row);
      n++;
    }
    return n;
  }

  Future<int> _pullRelationships(String userId) async {
    final rows = await _supabase
        .from('person_relationships')
        .select()
        .eq('user_id', userId);
    var n = 0;
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final clientId = (map['client_id'] as String?)?.trim();
      if (clientId == null || clientId.isEmpty) continue;

      final existing = await _relationshipDs.fetchById(clientId);
      if (existing != null && !existing.isSynced) continue;

      final row = RelationshipCollection()
        ..id = clientId
        ..personId = (map['person_id'] as String?)?.trim() ?? ''
        ..relatedPersonId = (map['related_person_id'] as String?)?.trim() ?? ''
        ..relationshipType = (map['relationship_type'] as String?)?.trim() ?? ''
        ..startDate = _parseDate(map['start_date'])
        ..endDate = _parseDate(map['end_date'])
        ..isCurrent = map['is_current'] as bool? ?? true
        ..supabaseId = map['id'] as String?
        ..isSynced = true
        ..isDeleted = false;

      if (existing != null) {
        row.isarId = existing.isarId;
      }

      await _relationshipDs.put(row);
      n++;
    }
    return n;
  }

  Future<(int, int)> _pullGroups(String userId) async {
    await _personGroupDs.ensureSeededAndMigrateLegacy(_personDs);

    final groupRows = await _supabase
        .from('person_groups')
        .select()
        .eq('user_id', userId);

    var groups = 0;
    for (final raw in groupRows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final clientId = (map['client_id'] as String?)?.trim();
      if (clientId == null || clientId.isEmpty) continue;

      final row = GroupCollection()
        ..id = clientId
        ..name = (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : clientId
        ..builtIn = map['built_in'] as bool? ?? false;
      await _personGroupDs.upsertGroup(row);
      groups++;
    }

    final linkRows = await _supabase
        .from('contact_person_group_links')
        .select()
        .eq('user_id', userId);

    var links = 0;
    for (final raw in linkRows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final pid = (map['person_client_id'] as String?)?.trim();
      final gid = (map['group_client_id'] as String?)?.trim();
      if (pid == null || gid == null) continue;
      await _personGroupDs.putPersonGroupLinkForImport(pid, gid);
      links++;
    }
    return (groups, links);
  }

  Future<int> _pullCustomCategories(String userId) async {
    final rows = await _supabase
        .from('custom_categories')
        .select()
        .eq('user_id', userId);
    var n = 0;
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final clientId = (map['client_id'] as String?)?.trim().toLowerCase();
      if (clientId == null ||
          clientId.isEmpty ||
          _builtInCategoryIds.contains(clientId)) {
        continue;
      }

      final row = CategoryCollection()
        ..id = clientId
        ..name = (map['name'] as String?)?.trim() ?? clientId
        ..iconName = (map['icon_name'] as String?)?.trim() ?? 'category'
        ..colorValue = _colorValue(map['color_value']);

      await _categoryDs.upsert(row);
      n++;
    }
    return n;
  }

  Future<int> _pullSavedLocations(String userId) async {
    final rows = await _supabase
        .from('saved_locations')
        .select()
        .eq('user_id', userId);
    var n = 0;
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final clientId = (map['client_id'] as String?)?.trim();
      if (clientId == null || clientId.isEmpty) continue;

      final existing = await _isar.savedLocationCollections
          .filter()
          .clientIdEqualTo(clientId)
          .findFirst();

      final row = existing ?? SavedLocationCollection();
      row
        ..clientId = clientId
        ..name = (map['name'] as String?)?.trim() ?? ''
        ..city = (map['city'] as String?)?.trim()
        ..country = (map['country'] as String?)?.trim()
        ..latitude = (map['latitude'] as num?)?.toDouble()
        ..longitude = (map['longitude'] as num?)?.toDouble();

      await _savedLocationDs.upsert(row);
      n++;
    }
    return n;
  }

  Future<int> _pullMilestones(String userId) async {
    final remoteModels = await _milestoneRemote.fetchMilestones();
    final linkRows = await _supabase
        .from('milestone_person_links')
        .select()
        .eq('user_id', userId);

    final linksByMilestone = <String, List<Map<String, dynamic>>>{};
    for (final raw in linkRows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final mid = (map['milestone_id'] as String?)?.trim();
      if (mid == null || mid.isEmpty) continue;
      linksByMilestone.putIfAbsent(mid, () => []).add(map);
    }

    var n = 0;
    for (final model in remoteModels) {
      final existing = await _milestoneDs.fetchCollectionById(model.id);
      if (existing != null && !existing.isSynced) continue;

      final collection = _milestoneFromRemote(model, existing, userId);
      final links = linksByMilestone[model.id] ?? const [];
      collection.participants = [
        for (final l in links)
          (l['person_client_id'] as String?)?.trim(),
      ].whereType<String>().where((id) => id.isNotEmpty).toList();
      collection.protagonists = [
        for (final l in links)
          if (l['is_protagonist'] == true)
            (l['person_client_id'] as String?)?.trim(),
      ].whereType<String>().where((id) => id.isNotEmpty).toList();

      if (collection.participants.isEmpty &&
          model.participantIds.isNotEmpty) {
        collection.participants = List<String>.from(model.participantIds);
      }

      await _milestoneDs.upsert(collection);
      n++;
    }
    return n;
  }

  MilestoneCollection _milestoneFromRemote(
    MilestoneModel model,
    MilestoneCollection? existing,
    String userId,
  ) {
    final base = MilestoneCollection.fromMilestone(model, SyncStatus.synced)
      ..userId = userId
      ..supabaseId = model.id
      ..isSynced = true;

    if (existing != null) {
      base.isarId = existing.isarId;
      if (existing.mediaItems.isNotEmpty) {
        base.mediaItems = existing.mediaItems;
      }
      if (existing.media.isNotEmpty) {
        base.media = existing.media;
      }
      base.galleryCoverIndex = existing.galleryCoverIndex;
      base.driveFolderId = existing.driveFolderId;
    }
    return base;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static int _colorValue(Object? raw) {
    if (raw is int) return raw & 0xFFFFFFFF;
    if (raw is num) return raw.toInt() & 0xFFFFFFFF;
    return 0xFF000000;
  }
}

class PremiumCloudPullResult {
  const PremiumCloudPullResult({
    this.people = 0,
    this.relationships = 0,
    this.milestones = 0,
    this.groups = 0,
    this.groupLinks = 0,
    this.categories = 0,
    this.locations = 0,
    this.errors = const [],
  });

  final int people;
  final int relationships;
  final int milestones;
  final int groups;
  final int groupLinks;
  final int categories;
  final int locations;
  final List<String> errors;

  int get total =>
      people + relationships + milestones + groups + categories + locations;

  bool get hasErrors => errors.isNotEmpty;
}
