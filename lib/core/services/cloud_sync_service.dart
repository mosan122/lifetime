import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../data/datasources/isar_milestone_datasource.dart';
import '../../domain/entities/milestone.dart';
import 'google_drive_service.dart';
import 'premium_service.dart';

class CloudSyncService {
  final PremiumService _premium;
  final GoogleSignIn _googleSignIn;
  final IsarMilestoneDataSource _milestones;

  var _running = false;

  CloudSyncService(
    this._premium,
    this._googleSignIn,
    this._milestones,
  );

  Future<void> syncIfNeeded(List<Milestone> milestones) async {
    if (!_premium.isPremium) return;
    if (_running) return;
    _running = true;

    try {
      final account = await _googleSignIn.attemptLightweightAuthentication() ??
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

      // Root folder for this app (created under user's Drive, limited by drive.file).
      final rootId = await driveService.getOrCreateFolder('LifeTime');

      for (final m in milestones) {
        // One-by-one upload to avoid saturating connection.
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
    } finally {
      _running = false;
    }
  }
}

