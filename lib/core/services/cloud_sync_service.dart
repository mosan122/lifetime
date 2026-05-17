import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/isar_milestone_datasource.dart';
import '../../domain/entities/milestone.dart';
import '../../core/notifiers/cloud_sync_activity_notifier.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import '../../features/milestones/data/models/local/milestone_media_prune.dart';
import 'drive_milestone_media_restore.dart';
import 'google_drive_auth.dart';
import 'google_drive_reauth_bridge.dart';
import 'google_drive_service.dart';
import 'google_sign_in_silent.dart';
import 'local_media_store.dart';
import 'premium_service.dart';

class CloudSyncService {
  CloudSyncService(
    this._premium,
    this._googleSignIn,
    this._milestones,
    this._people,
    this._reauthBridge,
    this._localMedia,
    this._syncActivity,
  );

  final PremiumService _premium;
  final GoogleSignIn _googleSignIn;
  final IsarMilestoneDataSource _milestones;
  final IsarPersonDataSource _people;
  final GoogleDriveReauthBridge _reauthBridge;
  final LocalMediaStore _localMedia;
  final CloudSyncActivityNotifier _syncActivity;

  static const _logName = 'CloudSyncService';
  static const _syncIfNeededMinInterval = Duration(minutes: 2);
  static const _mediaRestoreCooldown = Duration(minutes: 10);

  var _running = false;
  var _mediaRestoreRunning = false;
  DateTime? _lastSyncIfNeededAt;
  DateTime? _lastMediaRestoreAt;

  Future<GoogleDriveService?> _openDriveServiceSilently() async {
    final account = await googleSignInSilently(_googleSignIn);
    if (account == null) {
      developer.log(
        'Sincronización de Drive abortada: Requiere re-autenticación',
        name: _logName,
      );
      return null;
    }
    return GoogleDriveService(_googleSignIn);
  }

  /// Borra en Drive copias con el mismo nombre (deja la enlazada en Isar o la primera).
  Future<void> _pruneDuplicateDriveFiles(
    GoogleDriveService drive,
    String milestoneFolderId,
    String milestoneId,
  ) async {
    try {
      final fresh = await _milestones.fetchCollectionById(milestoneId);
      if (fresh == null) return;

      final keepIds = fresh.mediaItems
          .map((e) => e.driveFileId?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final listing = await drive.listFolderChildren(milestoneFolderId);
      final byName = <String, List<DriveListedFile>>{};
      for (final file in listing.files) {
        byName.putIfAbsent(file.name, () => []).add(file);
      }

      for (final group in byName.values) {
        if (group.length <= 1) continue;
        group.sort((a, b) {
          final aKeep = keepIds.contains(a.id);
          final bKeep = keepIds.contains(b.id);
          if (aKeep == bKeep) return 0;
          return aKeep ? -1 : 1;
        });
        for (var i = 1; i < group.length; i++) {
          try {
            await drive.deleteById(group[i].id);
            developer.log(
              'Drive: duplicado eliminado ${group[i].name}',
              name: _logName,
            );
          } catch (e) {
            developer.log(
              'No se pudo borrar duplicado ${group[i].id}: $e',
              name: _logName,
            );
          }
        }
      }
    } catch (e) {
      developer.log('pruneDuplicateDriveFiles: $e', name: _logName);
    }
  }

  void _onDriveAuthFailure(Object error) {
    if (!isGoogleDriveAuthError(error)) return;
    developer.log(
      'Drive: token inválido o permisos insuficientes ($error)',
      name: _logName,
    );
    _reauthBridge.requestReauth();
  }

  /// Borra en Drive los archivos de hitos/personas marcados con [isDeleted].
  Future<void> purgeDeletedFromDrive() async {
    if (!_premium.isPremium) return;

    final driveService = await _openDriveServiceSilently();
    if (driveService == null) return;

    final driveIds = <String>{};

    final deletedMilestones = await _milestones.fetchDeleted();
    for (final m in deletedMilestones) {
      final root = m.driveFileId?.trim();
      if (root != null && root.isNotEmpty) driveIds.add(root);
      final folder = m.driveFolderId?.trim();
      if (folder != null && folder.isNotEmpty) driveIds.add(folder);
      for (final item in m.mediaItems) {
        final fid = item.driveFileId?.trim();
        if (fid != null && fid.isNotEmpty) driveIds.add(fid);
      }
    }

    final deletedPeople = await _people.fetchDeleted();
    for (final p in deletedPeople) {
      final fid = p.driveFaceFileId?.trim();
      if (fid != null && fid.isNotEmpty) driveIds.add(fid);
    }

    final mediaPruneByMilestone = <String, Set<String>>{};
    final activeMilestones = await _milestones.fetchAll();
    for (final m in activeMilestones) {
      for (final item in m.mediaItems) {
        if (!item.isDeleted) continue;
        final fid = item.driveFileId?.trim();
        if (fid == null || fid.isEmpty) continue;
        driveIds.add(fid);
        mediaPruneByMilestone
            .putIfAbsent(m.id, () => {})
            .add(item.localPath);
      }
    }

    if (driveIds.isEmpty) {
      await _pruneDeletedMediaWithoutDriveId(activeMilestones);
      return;
    }

    for (final fileId in driveIds) {
      try {
        await driveService.deleteById(fileId);
      } on GoogleDriveAuthException catch (e) {
        _onDriveAuthFailure(e);
        return;
      } catch (e) {
        developer.log(
          'No se pudo borrar $fileId en Drive: $e',
          name: _logName,
        );
      }
    }

    if (mediaPruneByMilestone.isNotEmpty) {
      for (final entry in mediaPruneByMilestone.entries) {
        final raw = await _milestones.fetchCollectionById(entry.key);
        if (raw == null) continue;
        raw.pruneDeletedWithLocalPaths(entry.value);
        await _milestones.upsert(raw);
      }
    }
    await _pruneDeletedMediaWithoutDriveId(activeMilestones);
  }

  Future<void> _pruneDeletedMediaWithoutDriveId(
    List<MilestoneCollection> milestones,
  ) async {
    for (final m in milestones) {
      final raw = await _milestones.fetchCollectionById(m.id);
      if (raw == null) continue;
      final before = raw.mediaItems.length;
      raw.pruneDeletedWithoutDriveFile();
      if (raw.mediaItems.length != before) {
        await _milestones.upsert(raw);
      }
    }
  }

  Future<void> syncIfNeeded(List<Milestone> milestones) async {
    if (!_premium.isPremium) return;
    if (_running) return;

    final now = DateTime.now();
    if (_lastSyncIfNeededAt != null &&
        now.difference(_lastSyncIfNeededAt!) < _syncIfNeededMinInterval) {
      return;
    }
    _lastSyncIfNeededAt = now;

    _running = true;
    _syncActivity.acquire();

    try {
      final driveService = await _openDriveServiceSilently();
      if (driveService == null) return;

      final rootId = await driveService.getOrCreateBackupFolder();
      final mediaRootId =
          await driveService.getOrCreateFolder('Media', parentId: rootId);

      for (final m in milestones) {
        final raw = await _milestones.fetchCollectionById(m.id);
        if (raw == null) continue;

        final d = raw.eventDate;
        final yearId = await driveService.getOrCreateFolder(
          d.year.toString().padLeft(4, '0'),
          parentId: mediaRootId,
        );
        final monthId = await driveService.getOrCreateFolder(
          d.month.toString().padLeft(2, '0'),
          parentId: yearId,
        );
        final dayId = await driveService.getOrCreateFolder(
          d.day.toString().padLeft(2, '0'),
          parentId: monthId,
        );
        final milestoneFolderId = await driveService.getOrCreateFolder(
          raw.id,
          parentId: dayId,
        );
        await _milestones.setDriveFolderId(
          milestoneId: raw.id,
          driveFolderId: milestoneFolderId,
        );

        for (final item in raw.mediaItems) {
          if (item.isDeleted) continue;
          if (item.isSynced &&
              item.driveFileId != null &&
              item.driveFileId!.trim().isNotEmpty) {
            continue;
          }

          final path = item.localPath.trim();
          if (path.isEmpty) continue;
          final f = File(path);
          if (!await f.exists()) continue;

          try {
            developer.log(
              'Sincronizando archivo $path a Drive...',
              name: _logName,
            );

            final fileId =
                await driveService.uploadFile(f, milestoneFolderId);
            await _milestones.markMediaItemSynced(
              milestoneId: raw.id,
              localPath: path,
              driveFileId: fileId,
            );
          } on GoogleDriveAuthException catch (e) {
            _onDriveAuthFailure(e);
            return;
          }
        }

        await _pruneDuplicateDriveFiles(
          driveService,
          milestoneFolderId,
          raw.id,
        );
      }

      try {
        await syncPendingFaces(driveService, rootId);
      } on GoogleDriveAuthException catch (e) {
        _onDriveAuthFailure(e);
      }
    } on GoogleDriveAuthException catch (e) {
      _onDriveAuthFailure(e);
    } finally {
      _running = false;
      _syncActivity.release();
    }
  }

  /// Enlaza y descarga medios desde `LifeTime_App/Media/.../{milestoneId}/`.
  Future<DriveMediaRestoreResult> restoreMilestoneMediaFromDrive({
    bool force = false,
  }) async {
    if (!_premium.isPremium) return const DriveMediaRestoreResult();
    if (_mediaRestoreRunning) return const DriveMediaRestoreResult();

    if (!force &&
        _lastMediaRestoreAt != null &&
        DateTime.now().difference(_lastMediaRestoreAt!) <
            _mediaRestoreCooldown) {
      return const DriveMediaRestoreResult();
    }

    _mediaRestoreRunning = true;
    _syncActivity.acquire();
    try {
      final driveService = await _openDriveServiceSilently();
      if (driveService == null) return const DriveMediaRestoreResult();

      final result = await DriveMilestoneMediaRestore(_milestones, _localMedia)
          .run(driveService);
      _lastMediaRestoreAt = DateTime.now();
      return result;
    } on GoogleDriveAuthException catch (e) {
      _onDriveAuthFailure(e);
      return const DriveMediaRestoreResult();
    } catch (e) {
      developer.log('restoreMilestoneMediaFromDrive: $e', name: _logName);
      return const DriveMediaRestoreResult();
    } finally {
      _mediaRestoreRunning = false;
      _syncActivity.release();
    }
  }

  Future<void> restoreMissingFaces() async {
    if (!_premium.isPremium) return;
    if (_running) return;
    try {
      final driveService = await _openDriveServiceSilently();
      if (driveService == null) return;
      await restoreFacesWithService(driveService);
    } on GoogleDriveAuthException catch (e) {
      _onDriveAuthFailure(e);
    } catch (e) {
      developer.log('restoreMissingFaces failed: $e', name: _logName);
    }
  }

  @visibleForTesting
  Future<void> syncPendingFaces(
      GoogleDriveService driveService, String rootId) async {
    final people = await _people.fetchAll();
    final pending = people
        .where((p) =>
            p.faceImagePath != null &&
            p.driveFaceFileId == null &&
            File(p.faceImagePath!).existsSync())
        .toList();
    if (pending.isEmpty) return;

    final peopleId =
        await driveService.getOrCreateFolder('People', parentId: rootId);

    for (final p in pending) {
      try {
        final fileId =
            await driveService.uploadFile(File(p.faceImagePath!), peopleId);
        final updated = p.copyScalars()
          ..faceImagePath = p.faceImagePath
          ..driveFaceFileId = fileId;
        await _people.upsert(updated);
        developer.log('Cara sincronizada para ${p.id}', name: _logName);
      } on GoogleDriveAuthException catch (e) {
        _onDriveAuthFailure(e);
        return;
      } catch (e) {
        developer.log(
          'Error sincronizando cara para ${p.id}: $e',
          name: _logName,
        );
      }
    }
  }

  Future<void> deleteDriveFace(String fileId) async {
    if (!_premium.isPremium) return;
    try {
      final driveService = await _openDriveServiceSilently();
      if (driveService == null) return;
      await deleteFaceFromDriveWithService(driveService, fileId);
    } on GoogleDriveAuthException catch (e) {
      _onDriveAuthFailure(e);
    } catch (e) {
      developer.log('deleteDriveFace failed: $e', name: _logName);
    }
  }

  @visibleForTesting
  Future<void> deleteFaceFromDriveWithService(
      GoogleDriveService driveService, String fileId) async {
    await driveService.deleteById(fileId);
  }

  @visibleForTesting
  Future<void> restoreFacesWithService(GoogleDriveService driveService) async {
    final appDir = await getApplicationDocumentsDirectory();
    final people = await _people.fetchAll();

    for (final p in people) {
      if (p.driveFaceFileId == null) continue;

      final pathMissing = p.faceImagePath == null ||
          !File(p.faceImagePath!).existsSync();
      if (!pathMissing) continue;

      try {
        final destPath = '${appDir.path}/faces/${p.id}.jpg';
        await driveService.downloadFile(p.driveFaceFileId!, destPath);
        final updated = p.copyScalars()
          ..faceImagePath = destPath
          ..driveFaceFileId = p.driveFaceFileId;
        await _people.upsert(updated);
        developer.log('Cara restaurada para ${p.id}', name: _logName);
      } on GoogleDriveAuthException catch (e) {
        _onDriveAuthFailure(e);
        return;
      } catch (e) {
        developer.log(
          'Error restaurando cara para ${p.id}: $e',
          name: _logName,
        );
      }
    }
  }
}
