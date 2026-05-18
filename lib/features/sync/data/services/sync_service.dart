import 'dart:developer' as developer;
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/notifiers/cloud_sync_activity_notifier.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/cloud_sync_status_store.dart';
import '../../../../core/services/local_media_store.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../core/constants/milestone_category_seeds.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../../data/datasources/milestone_remote_datasource.dart';
import '../../../../data/models/milestone_model.dart';
import '../../../milestones/data/datasources/isar_category_datasource.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/datasources/isar_relationship_datasource.dart';
import '../../../milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/milestone_collection.dart';
import '../../../milestones/data/models/local/milestone_media_prune.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/data/models/local/relationship_collection.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../domain/sync_run_result.dart';
import 'premium_cloud_pull.dart';

/// Sincronización incremental Isar → nube (Drive + Supabase), solo premium.
class SyncService {
  SyncService(
    this._supabase,
    this._isar,
    this._premium,
    this._profileRemote,
    this._cloudSync,
    this._milestoneRemote,
    this._milestoneDs,
    this._personDs,
    this._relationshipDs,
    this._personGroupDs,
    this._categoryDs,
    this._savedLocationDs,
    this._localMedia,
    this._syncActivity,
    this._syncStatus,
  );

  final SupabaseClient _supabase;
  final Isar _isar;
  final PremiumService _premium;
  final ProfileRemoteDataSource _profileRemote;
  final CloudSyncService _cloudSync;
  final MilestoneRemoteDataSource _milestoneRemote;
  final IsarMilestoneDataSource _milestoneDs;
  final IsarPersonDataSource _personDs;
  final IsarRelationshipDataSource _relationshipDs;
  final PersonGroupLocalDataSource _personGroupDs;
  final IsarCategoryDataSource _categoryDs;
  final IsarSavedLocationDataSource _savedLocationDs;
  final LocalMediaStore _localMedia;
  final CloudSyncActivityNotifier _syncActivity;
  final CloudSyncStatusStore _syncStatus;

  PremiumCloudPull get _cloudPull => PremiumCloudPull(
        _supabase,
        _isar,
        _milestoneRemote,
        _milestoneDs,
        _personDs,
        _relationshipDs,
        _personGroupDs,
        _categoryDs,
        _savedLocationDs,
      );

  static Set<String> get _builtInCategoryIds => {
        for (final s in kMilestoneCategorySeeds) s.id.toLowerCase(),
      };

  /// ARGB 32 bits sin signo (Flutter puede usar int con bit alto a 1).
  static int _colorArgbForSupabase(int colorValue) => colorValue & 0xFFFFFFFF;

  static const _logName = 'SyncService';
  var _running = false;

  SyncRunResult? lastResult;

  /// Primera apertura del timeline tras login premium: pull + push completos.
  Future<void> syncIfNeededForTimelineOpen() async {
    if (!await _resolveIsPremium()) return;
    if (!await _syncStatus.consumeNeedsTimelinePull()) return;
    await syncData();
  }

  /// Marca todo el contenido local activo como pendiente de subir a Supabase.
  Future<void> markAllLocalRowsPending() async {
    await _isar.writeTxn(() async {
      final people = await _isar.personCollections
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      for (final p in people) {
        p.isSynced = false;
        await _isar.personCollections.put(p);
      }

      final rels = await _isar.relationshipCollections
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      for (final r in rels) {
        r.isSynced = false;
        await _isar.relationshipCollections.put(r);
      }

      final milestones = await _isar.milestoneCollections
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      for (final m in milestones) {
        m.isSynced = false;
        m.syncStatus = SyncStatus.pending;
        await _isar.milestoneCollections.put(m);
      }
    });
  }

  Future<SyncRunResult> syncData({bool forceResync = false}) async {
    if (_running) {
      return const SyncRunResult(
        skipped: true,
        skipReason: 'Ya hay una sincronización en curso.',
      );
    }

    if (!await _resolveIsPremium()) {
      developer.log(
        'Sincronización omitida: Usuario básico',
        name: _logName,
      );
      return const SyncRunResult(
        skipped: true,
        skipReason: 'Se requiere cuenta Premium.',
      );
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      developer.log('Sincronización omitida: sin sesión', name: _logName);
      return const SyncRunResult(
        skipped: true,
        skipReason: 'Inicia sesión para sincronizar.',
      );
    }

    _running = true;
    _syncActivity.acquire();
    final errors = <String>[];
    var peopleSynced = 0;
    var peopleFailed = 0;
    var relSynced = 0;
    var relFailed = 0;
    var msSynced = 0;
    var msFailed = 0;

    try {
      final pull = await _cloudPull.pullAll(user.id);
      errors.addAll(pull.errors);
      developer.log(
        'Pull nube: ${pull.total} filas (hitos ${pull.milestones}, personas ${pull.people})',
        name: _logName,
      );

      if (forceResync) {
        await markAllLocalRowsPending();
      }

      await _cloudSync.purgeDeletedFromDrive();
      await _purgeDeletedFromSupabase(user.id);

      await _syncCatalog(user.id);

      final pr = await _syncPeople(user.id);
      peopleSynced = pr.$1;
      peopleFailed = pr.$2;
      errors.addAll(pr.$3);

      final rr = await _syncRelationships(user.id);
      relSynced = rr.$1;
      relFailed = rr.$2;
      errors.addAll(rr.$3);

      final mr = await _syncMilestones(user.id);
      msSynced = mr.$1;
      msFailed = mr.$2;
      errors.addAll(mr.$3);

      final milestones = await _milestoneDs.fetchAll();
      if (msFailed == 0 && milestones.isNotEmpty) {
        final domain = milestones.map((m) => m.toDomain()).toList();
        await _cloudSync.syncIfNeeded(domain);
      }

      await _cloudSync.restoreMilestoneMediaFromDrive(
        force: forceResync || pull.milestones > 0,
      );
      await _cloudSync.restoreMissingFaces();
    } catch (e, st) {
      developer.log(
        'Error en sincronización: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      errors.add(_formatError(e));
    } finally {
      _running = false;
      _syncActivity.release();
    }

    final result = SyncRunResult(
      peopleSynced: peopleSynced,
      peopleFailed: peopleFailed,
      relationshipsSynced: relSynced,
      relationshipsFailed: relFailed,
      milestonesSynced: msSynced,
      milestonesFailed: msFailed,
      errors: errors,
    );
    lastResult = result;
    if (!result.skipped && !result.hasErrors) {
      await _syncStatus.recordSuccess(DateTime.now().toUtc());
    }
    return result;
  }

  Future<bool> _resolveIsPremium() async {
    if (_premium.isPremium) return true;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      return await _profileRemote.fetchIsPremium(userId);
    } catch (_) {
      return false;
    }
  }

  static String _formatError(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      final msg = e.message;
      if (code == '42P01' || msg.contains('does not exist')) {
        return 'Falta una tabla en Supabase. Ejecuta las migraciones del proyecto '
            '(contact_people, person_relationships, milestone_person_links).';
      }
      if (code == '23502' && msg.contains('milestone_date')) {
        return 'Falta la fecha del hito (milestone_date). Actualiza la app y sincroniza de nuevo.';
      }
      if (code == 'PGRST204') {
        if (msg.contains('category')) {
          return 'Falta la columna category en milestones. Ejecuta: supabase db push';
        }
        if (msg.contains('color_value')) {
          return 'Columna color_value debe ser bigint. Ejecuta: supabase db push';
        }
        if (msg.contains('milestone_date')) {
          return 'Falta la columna milestone_date en milestones. Ejecuta: supabase db push';
        }
        return 'Esquema de milestones incompleto en Supabase. Ejecuta: supabase db push';
      }
      return 'Supabase ($code): $msg';
    }
    return e.toString();
  }

  bool _isRemoteNotFound(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST116') return true;
      final msg = (error.message).toLowerCase();
      if (msg.contains('0 rows') || msg.contains('not found')) return true;
    }
    return false;
  }

  Future<void> _purgeDeletedFromSupabase(String userId) async {
    await _purgeDeletedMilestones();
    await _purgeDeletedRelationships(userId);
    await _purgeDeletedPeople(userId);
  }

  Future<void> _purgeDeletedMilestones() async {
    final deleted = await _milestoneDs.fetchDeleted();
    for (final m in deleted) {
      final remoteId = m.supabaseId?.trim() ?? m.id;
      if (remoteId.isNotEmpty) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId == null) continue;
          await _supabase
              .from('milestone_person_links')
              .delete()
              .eq('user_id', userId)
              .eq('milestone_id', remoteId);
          await _supabase
              .from('milestones')
              .delete()
              .eq('id', remoteId)
              .eq('user_id', userId);
        } catch (e) {
          if (!_isRemoteNotFound(e)) {
            developer.log(
              'Supabase: hito ${m.id} no borrado: $e',
              name: _logName,
            );
            continue;
          }
        }
      }
      await _hardDeleteMilestoneLocal(m);
    }
  }

  Future<void> _hardDeleteMilestoneLocal(MilestoneCollection m) async {
    try {
      await _localMedia.deleteFolder(m.eventDate, m.id);
    } catch (_) {}
    await _milestoneDs.hardDelete(m);
  }

  Future<void> _purgeDeletedRelationships(String userId) async {
    final deleted = await _relationshipDs.fetchDeleted();
    for (final r in deleted) {
      final remoteId = r.supabaseId?.trim();
      if (remoteId != null && remoteId.isNotEmpty) {
        try {
          await _supabase
              .from('person_relationships')
              .delete()
              .eq('id', remoteId)
              .eq('user_id', userId);
        } catch (e) {
          if (!_isRemoteNotFound(e)) {
            developer.log(
              'Supabase: relación ${r.id} no borrada: $e',
              name: _logName,
            );
            continue;
          }
        }
      }
      await _relationshipDs.hardDelete(r);
    }
  }

  Future<void> _purgeDeletedPeople(String userId) async {
    final deleted = await _personDs.fetchDeleted();
    for (final p in deleted) {
      final remoteId = p.supabaseId?.trim();
      if (remoteId != null && remoteId.isNotEmpty) {
        try {
          await _supabase
              .from('contact_people')
              .delete()
              .eq('id', remoteId)
              .eq('user_id', userId);
        } catch (e) {
          if (!_isRemoteNotFound(e)) {
            developer.log(
              'Supabase: persona ${p.id} no borrada: $e',
              name: _logName,
            );
            continue;
          }
        }
      }
      final fp = p.faceImagePath?.trim();
      if (fp != null && fp.isNotEmpty) {
        try {
          final file = File(fp);
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      await _personDs.hardDelete(p);
    }
  }

  bool _personNeedsSync(PersonCollection p) =>
      !p.isSynced || (p.supabaseId == null || p.supabaseId!.trim().isEmpty);

  bool _relationshipNeedsSync(RelationshipCollection r) =>
      !r.isSynced || (r.supabaseId == null || r.supabaseId!.trim().isEmpty);

  bool _milestoneNeedsSync(MilestoneCollection m) =>
      !m.isSynced || (m.supabaseId == null || m.supabaseId!.trim().isEmpty);

  DateTime _effectiveMilestoneDate(MilestoneCollection m) {
    if (m.eventDate.millisecondsSinceEpoch > 0) return m.eventDate;
    if (m.createdAt.millisecondsSinceEpoch > 0) return m.createdAt;
    return DateTime.now();
  }

  Future<(int, int, List<String>)> _syncPeople(String userId) async {
    final all = await _isar.personCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final pending = all.where(_personNeedsSync).toList();
    if (pending.isEmpty) return (0, 0, <String>[]);

    var ok = 0;
    var fail = 0;
    final errors = <String>[];

    for (final p in pending) {
      try {
        final payload = _personPayload(p, userId);
        final row = await _supabase
            .from('contact_people')
            .upsert(
              payload,
              onConflict: 'user_id,client_id',
            )
            .select('id')
            .single();
        p.supabaseId = row['id'] as String;
        p.isSynced = true;
        await _isar.writeTxn(() => _isar.personCollections.put(p));
        ok++;
      } catch (e, st) {
        fail++;
        final msg = 'Persona «${p.name}»: ${_formatError(e)}';
        errors.add(msg);
        developer.log(msg, name: _logName, error: e, stackTrace: st);
      }
    }
    return (ok, fail, errors);
  }

  Map<String, dynamic> _personPayload(PersonCollection p, String userId) {
    return {
      'user_id': userId,
      'client_id': p.id,
      'name': p.name,
      if (p.firstName != null) 'first_name': p.firstName,
      if (p.lastName != null) 'last_name': p.lastName,
      if (p.birthDate != null) 'birth_date': p.birthDate!.toIso8601String(),
      'notes': p.notes,
      if (p.linkedUserEmail != null) 'linked_user_email': p.linkedUserEmail,
      if (p.linkedUserId != null) 'linked_user_id': p.linkedUserId,
      if (p.driveFaceFileId != null) 'drive_face_file_id': p.driveFaceFileId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<(int, int, List<String>)> _syncRelationships(String userId) async {
    final all = await _isar.relationshipCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final pending = all.where(_relationshipNeedsSync).toList();
    if (pending.isEmpty) return (0, 0, <String>[]);

    var ok = 0;
    var fail = 0;
    final errors = <String>[];

    for (final r in pending) {
      try {
        final payload = _relationshipPayload(r, userId);
        final row = await _supabase
            .from('person_relationships')
            .upsert(
              payload,
              onConflict: 'user_id,client_id',
            )
            .select('id')
            .single();
        r.supabaseId = row['id'] as String;
        r.isSynced = true;
        await _isar.writeTxn(() => _isar.relationshipCollections.put(r));
        ok++;
      } catch (e, st) {
        fail++;
        final msg = 'Relación ${r.id}: ${_formatError(e)}';
        errors.add(msg);
        developer.log(msg, name: _logName, error: e, stackTrace: st);
      }
    }
    return (ok, fail, errors);
  }

  Map<String, dynamic> _relationshipPayload(
    RelationshipCollection r,
    String userId,
  ) {
    return {
      'user_id': userId,
      'client_id': r.id,
      'person_id': r.personId,
      'related_person_id': r.relatedPersonId,
      'relationship_type': r.relationshipType,
      if (r.startDate != null) 'start_date': r.startDate!.toIso8601String(),
      if (r.endDate != null) 'end_date': r.endDate!.toIso8601String(),
      'is_current': r.isCurrent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _syncMilestonePersonLinks(
    String userId,
    MilestoneCollection m,
    String milestoneRemoteId,
  ) async {
    await _supabase
        .from('milestone_person_links')
        .delete()
        .eq('user_id', userId)
        .eq('milestone_id', milestoneRemoteId);

    if (m.participants.isEmpty) return;

    final rows = m.participants.map((personId) {
      return {
        'user_id': userId,
        'milestone_id': milestoneRemoteId,
        'person_client_id': personId,
        'is_protagonist': m.protagonists.contains(personId),
      };
    }).toList();

    await _supabase.from('milestone_person_links').insert(rows);
  }

  Future<(int, int, List<String>)> _syncMilestones(String userId) async {
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final pending = all.where(_milestoneNeedsSync).toList();
    if (pending.isEmpty) return (0, 0, <String>[]);

    var ok = 0;
    var fail = 0;
    final errors = <String>[];

    for (final m in pending) {
      try {
        final loc = m.location;
        final locationName = (loc?.name?.trim().isNotEmpty ?? false)
            ? loc!.name!.trim()
            : m.locationName;
        final latitude = loc?.latitude ?? m.latitude;
        final longitude = loc?.longitude ?? m.longitude;
        final categoryId = (m.categoryId == null || m.categoryId!.trim().isEmpty)
            ? 'otros'
            : m.categoryId!.trim().toLowerCase();

        final insertMap = MilestoneModel.toInsertMap(
          title: m.title,
          description: m.description,
          participantIds: m.participants,
          protagonistIds: m.protagonists,
          tags: m.tags,
          eventDate: _effectiveMilestoneDate(m),
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          categoryId: categoryId,
          isPublic: m.isPublic,
          driveFileId: m.driveFileId,
        );

        final response = await _supabase
            .from('milestones')
            .upsert(
              {
                ...insertMap,
                'id': m.id,
                'user_id': userId,
              },
              onConflict: 'id',
            )
            .select('id')
            .single();

        final remoteId = response['id'] as String;
        m.supabaseId = remoteId;

        try {
          await _syncMilestonePersonLinks(userId, m, remoteId);
        } catch (e) {
          errors.add('Enlaces del hito «${m.title}»: ${_formatError(e)}');
          developer.log(
            'Enlaces hito ${m.id}: $e',
            name: _logName,
          );
        }

        m.pruneDeletedWithoutDriveFile();

        m.isSynced = true;
        m.syncStatus = SyncStatus.synced;
        await _isar.writeTxn(() => _isar.milestoneCollections.put(m));
        ok++;
      } catch (e, st) {
        fail++;
        final msg = 'Hito «${m.title}»: ${_formatError(e)}';
        errors.add(msg);
        developer.log(msg, name: _logName, error: e, stackTrace: st);
      }
    }
    return (ok, fail, errors);
  }

  /// Grupos, categorías custom y lugares favoritos → Supabase.
  Future<void> _syncCatalog(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final groups = await _personGroupDs.fetchAllGroupsOrdered();
    for (final g in groups) {
      await _supabase.from('person_groups').upsert(
        {
          'user_id': userId,
          'client_id': g.id,
          'name': g.name,
          'built_in': g.builtIn,
          'updated_at': now,
        },
        onConflict: 'user_id,client_id',
      );
    }

    final links = await _personGroupDs.fetchAllLinks();
    await _supabase
        .from('contact_person_group_links')
        .delete()
        .eq('user_id', userId);
    if (links.isNotEmpty) {
      await _supabase.from('contact_person_group_links').insert(
        links
            .map(
              (l) => {
                'user_id': userId,
                'person_client_id': l.personId,
                'group_client_id': l.groupId,
              },
            )
            .toList(),
      );
    }

    final categories = await _categoryDs.fetchAll();
    for (final c in categories) {
      final id = c.id.trim().toLowerCase();
      if (id.isEmpty || _builtInCategoryIds.contains(id)) continue;
      await _supabase.from('custom_categories').upsert(
        {
          'user_id': userId,
          'client_id': id,
          'name': c.name,
          'icon_name': c.iconName,
          'color_value': _colorArgbForSupabase(c.colorValue),
          'updated_at': now,
        },
        onConflict: 'user_id,client_id',
      );
    }

    final locations = await _savedLocationDs.fetchAll();
    for (final loc in locations) {
      final saved = await _savedLocationDs.upsert(loc);
      await _supabase.from('saved_locations').upsert(
        {
          'user_id': userId,
          'client_id': saved.clientId,
          'name': saved.name,
          if (saved.city != null) 'city': saved.city,
          if (saved.country != null) 'country': saved.country,
          if (saved.latitude != null) 'latitude': saved.latitude,
          if (saved.longitude != null) 'longitude': saved.longitude,
          'updated_at': now,
        },
        onConflict: 'user_id,client_id',
      );
    }
  }
}
