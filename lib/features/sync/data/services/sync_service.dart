import 'dart:developer' as developer;
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/local_media_store.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../../data/datasources/milestone_remote_datasource.dart';
import '../../../../data/models/milestone_model.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/datasources/isar_relationship_datasource.dart';
import '../../../milestones/data/models/local/milestone_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/data/models/local/relationship_collection.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';

/// Sincronización incremental Isar → nube (Drive + Supabase), solo premium.
class SyncService {
  SyncService(
    this._supabase,
    this._isar,
    this._premium,
    this._milestoneRemote,
    this._profileRemote,
    this._cloudSync,
    this._milestoneDs,
    this._personDs,
    this._relationshipDs,
    this._localMedia,
  );

  final SupabaseClient _supabase;
  final Isar _isar;
  final PremiumService _premium;
  final MilestoneRemoteDataSource _milestoneRemote;
  final ProfileRemoteDataSource _profileRemote;
  final CloudSyncService _cloudSync;
  final IsarMilestoneDataSource _milestoneDs;
  final IsarPersonDataSource _personDs;
  final IsarRelationshipDataSource _relationshipDs;
  final LocalMediaStore _localMedia;

  static const _logName = 'SyncService';
  var _running = false;

  Future<void> syncData() async {
    if (_running) return;

    if (!await _resolveIsPremium()) {
      developer.log(
        'Sincronización omitida: Usuario básico',
        name: _logName,
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      developer.log('Sincronización omitida: sin sesión', name: _logName);
      return;
    }

    _running = true;
    try {
      await _cloudSync.purgeDeletedFromDrive();
      await _purgeDeletedFromSupabase(user.id);
      await _syncPeople(user.id);
      await _syncRelationships(user.id);
      await _syncMilestones(user.id);
    } catch (e, st) {
      developer.log(
        'Error en sincronización: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    } finally {
      _running = false;
    }
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
      final remoteId = m.supabaseId?.trim();
      if (remoteId != null && remoteId.isNotEmpty) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            await _supabase
                .from('milestone_person_links')
                .delete()
                .eq('user_id', userId)
                .eq('milestone_id', remoteId);
          }
          await _milestoneRemote.deleteMilestone(remoteId);
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
    } catch (_) {
      // Best-effort.
    }
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

  Future<void> _syncPeople(String userId) async {
    final pending = await _isar.personCollections
        .filter()
        .isDeletedEqualTo(false)
        .isSyncedEqualTo(false)
        .findAll();
    if (pending.isEmpty) return;

    for (final p in pending) {
      try {
        final payload = _personPayload(p, userId);
        if (p.supabaseId == null) {
          final row = await _supabase
              .from('contact_people')
              .insert(payload)
              .select('id')
              .single();
          p.supabaseId = row['id'] as String;
        } else {
          await _supabase.from('contact_people').upsert({
            ...payload,
            'id': p.supabaseId,
          });
        }
        p.isSynced = true;
        await _isar.writeTxn(() => _isar.personCollections.put(p));
      } catch (e, st) {
        developer.log(
          'Persona ${p.id} no sincronizada: $e',
          name: _logName,
          error: e,
          stackTrace: st,
        );
      }
    }
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

  Future<void> _syncRelationships(String userId) async {
    final pending = await _isar.relationshipCollections
        .filter()
        .isDeletedEqualTo(false)
        .isSyncedEqualTo(false)
        .findAll();
    if (pending.isEmpty) return;

    for (final r in pending) {
      try {
        final payload = _relationshipPayload(r, userId);
        if (r.supabaseId == null) {
          final row = await _supabase
              .from('person_relationships')
              .insert(payload)
              .select('id')
              .single();
          r.supabaseId = row['id'] as String;
        } else {
          await _supabase.from('person_relationships').upsert({
            ...payload,
            'id': r.supabaseId,
          });
        }
        r.isSynced = true;
        await _isar.writeTxn(() => _isar.relationshipCollections.put(r));
      } catch (e, st) {
        developer.log(
          'Relación ${r.id} no sincronizada: $e',
          name: _logName,
          error: e,
          stackTrace: st,
        );
      }
    }
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
  ) async {
    final milestoneId = m.supabaseId ?? m.id;
    await _supabase
        .from('milestone_person_links')
        .delete()
        .eq('user_id', userId)
        .eq('milestone_id', milestoneId);

    if (m.participants.isEmpty) return;

    final rows = m.participants.map((personId) {
      return {
        'user_id': userId,
        'milestone_id': milestoneId,
        'person_client_id': personId,
        'is_protagonist': m.protagonists.contains(personId),
      };
    }).toList();

    await _supabase.from('milestone_person_links').insert(rows);
  }

  Future<void> _syncMilestones(String userId) async {
    final pending = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .isSyncedEqualTo(false)
        .findAll();
    if (pending.isEmpty) return;

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
          participants: const [],
          participantIds: m.participants,
          protagonistIds: m.protagonists,
          tags: m.tags,
          eventDate: m.eventDate,
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          categoryId: categoryId,
          isPublic: m.isPublic,
          driveFileId: m.driveFileId,
        );

        final remoteId = m.supabaseId ?? m.id;
        await _milestoneRemote.upsertMilestone(remoteId, insertMap);
        m.supabaseId = remoteId;

        await _syncMilestonePersonLinks(userId, m);

        m.mediaItems.removeWhere(
          (e) =>
              e.isDeleted &&
              (e.driveFileId == null || e.driveFileId!.trim().isEmpty),
        );

        m.isSynced = true;
        m.syncStatus = SyncStatus.synced;
        await _isar.writeTxn(() => _isar.milestoneCollections.put(m));
      } catch (e, st) {
        developer.log(
          'Hito ${m.id} no sincronizado: $e',
          name: _logName,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
