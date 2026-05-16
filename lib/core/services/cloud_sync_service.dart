import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/isar_milestone_datasource.dart';
import '../../domain/entities/milestone.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import 'google_drive_auth.dart';
import 'google_drive_reauth_bridge.dart';
import 'google_drive_service.dart';
import 'google_sign_in_silent.dart';
import 'premium_service.dart';

class CloudSyncService {
  CloudSyncService(
    this._premium,
    this._googleSignIn,
    this._milestones,
    this._people,
    this._reauthBridge,
  );

  final PremiumService _premium;
  final GoogleSignIn _googleSignIn;
  final IsarMilestoneDataSource _milestones;
  final IsarPersonDataSource _people;
  final GoogleDriveReauthBridge _reauthBridge;

  static const _logName = 'CloudSyncService';
  var _running = false;

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
        raw.mediaItems.removeWhere(
          (e) => e.isDeleted && entry.value.contains(e.localPath),
        );
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
      raw.mediaItems.removeWhere(
        (e) =>
            e.isDeleted &&
            (e.driveFileId == null || e.driveFileId!.trim().isEmpty),
      );
      if (raw.mediaItems.length != before) {
        await _milestones.upsert(raw);
      }
    }
  }

  Future<void> syncIfNeeded(List<Milestone> milestones) async {
    if (!_premium.isPremium) return;
    if (_running) return;
    _running = true;

    try {
      final driveService = await _openDriveServiceSilently();
      if (driveService == null) return;

      final rootId = await driveService.getOrCreateBackupFolder();
      final mediaRootId =
          await driveService.getOrCreateFolder('Media', parentId: rootId);

      for (final m in milestones) {
        for (final item in m.mediaItems) {
          if (item.isDeleted) continue;
          if (item.isSynced) continue;
          if (item.driveFileId != null) continue;

          final path = item.localPath;
          if (path.trim().isEmpty) continue;
          final f = File(path);
          if (!await f.exists()) continue;

          try {
            final d = m.eventDate;
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
              m.id,
              parentId: dayId,
            );
            await _milestones.setDriveFolderId(
              milestoneId: m.id,
              driveFolderId: milestoneFolderId,
            );

            developer.log(
              'Sincronizando archivo $path a Drive...',
              name: _logName,
            );

            final fileId = await driveService.uploadFile(f, milestoneFolderId);
            await _milestones.markMediaItemSynced(
              milestoneId: m.id,
              localPath: path,
              driveFileId: fileId,
            );
          } on GoogleDriveAuthException catch (e) {
            _onDriveAuthFailure(e);
            return;
          }
        }
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
