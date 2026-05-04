import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/isar_milestone_datasource.dart';
import '../../domain/entities/milestone.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/models/local/person_collection.dart';
import 'google_drive_service.dart';
import 'premium_service.dart';

class CloudSyncService {
  final PremiumService _premium;
  final GoogleSignIn _googleSignIn;
  final IsarMilestoneDataSource _milestones;
  final IsarPersonDataSource _people;

  var _running = false;

  CloudSyncService(
    this._premium,
    this._googleSignIn,
    this._milestones,
    this._people,
  );

  Future<void> syncIfNeeded(List<Milestone> milestones) async {
    if (!_premium.isPremium) return;
    if (_running) return;
    _running = true;

    try {
      final account =
          await _googleSignIn.attemptLightweightAuthentication() ??
              await _googleSignIn.authenticate(
                scopeHint: const ['https://www.googleapis.com/auth/drive.file'],
              );
      final authorization = await account.authorizationClient.authorizeScopes(
        const ['https://www.googleapis.com/auth/drive.file'],
      );
      final headers = <String, String>{
        'Authorization': 'Bearer ${authorization.accessToken}',
      };
      final client = GoogleAuthHttpClient(headers);
      final api = drive.DriveApi(client);
      final driveService = GoogleDriveService(api);

      final rootId = await driveService.getOrCreateFolder('LifeTime');

      for (final m in milestones) {
        for (final item in m.mediaItems) {
          if (item.isSynced) continue;
          if (item.driveFileId != null) continue;

          final path = item.localPath;
          if (path.trim().isEmpty) continue;
          final f = File(path);
          if (!await f.exists()) continue;

          final d = m.eventDate;
          final yearId = await driveService.getOrCreateFolder(
            d.year.toString().padLeft(4, '0'),
            parentId: rootId,
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

          // ignore: avoid_print
          print('Sincronizando archivo $path a Drive...');

          final fileId = await driveService.uploadFile(f, milestoneFolderId);
          await _milestones.markMediaItemSynced(
            milestoneId: m.id,
            localPath: path,
            driveFileId: fileId,
          );
        }
      }

      await syncPendingFaces(driveService, rootId);
    } finally {
      _running = false;
    }
  }

  Future<void> restoreMissingFaces() async {
    if (!_premium.isPremium) return;
    if (_running) return;
    try {
      final account =
          await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) return;
      final authorization = await account.authorizationClient.authorizeScopes(
        const ['https://www.googleapis.com/auth/drive.file'],
      );
      final headers = <String, String>{
        'Authorization': 'Bearer ${authorization.accessToken}',
      };
      final client = GoogleAuthHttpClient(headers);
      final api = drive.DriveApi(client);
      final driveService = GoogleDriveService(api);
      await restoreFacesWithService(driveService);
    } catch (e) {
      // ignore: avoid_print
      print('restoreMissingFaces failed: $e');
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

    final systemId =
        await driveService.getOrCreateFolder('System', parentId: rootId);
    final peopleId =
        await driveService.getOrCreateFolder('People', parentId: systemId);

    for (final p in pending) {
      try {
        final fileId = await driveService.uploadFile(File(p.faceImagePath!), peopleId);
        final updated = PersonCollection()
          ..isarId = p.isarId
          ..id = p.id
          ..name = p.name
          ..faceImagePath = p.faceImagePath
          ..driveFaceFileId = fileId;
        await _people.upsert(updated);
        // ignore: avoid_print
        print('Cara sincronizada para ${p.id}');
      } catch (e) {
        // ignore: avoid_print
        print('Error sincronizando cara para ${p.id}: $e');
      }
    }
  }

  Future<void> deleteDriveFace(String fileId) async {
    if (!_premium.isPremium) return;
    try {
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) return;
      final authorization = await account.authorizationClient.authorizeScopes(
        const ['https://www.googleapis.com/auth/drive.file'],
      );
      final headers = <String, String>{
        'Authorization': 'Bearer ${authorization.accessToken}',
      };
      final client = GoogleAuthHttpClient(headers);
      final api = drive.DriveApi(client);
      final driveService = GoogleDriveService(api);
      await deleteFaceFromDriveWithService(driveService, fileId);
    } catch (e) {
      // ignore: avoid_print
      print('deleteDriveFace failed: $e');
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
        final updated = PersonCollection()
          ..isarId = p.isarId
          ..id = p.id
          ..name = p.name
          ..faceImagePath = destPath
          ..driveFaceFileId = p.driveFaceFileId;
        await _people.upsert(updated);
        // ignore: avoid_print
        print('Cara restaurada para ${p.id}');
      } catch (e) {
        // ignore: avoid_print
        print('Error restaurando cara para ${p.id}: $e');
      }
    }
  }
}
