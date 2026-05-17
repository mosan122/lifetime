import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/sync/data/services/sync_pending_service.dart';
import '../../features/sync/domain/sync_pending_counts.dart';
import 'google_drive_service.dart';
import 'google_sign_in_silent.dart';

class StorageMetricsSnapshot {
  const StorageMetricsSnapshot({
    required this.localBytes,
    this.driveUsageBytes,
    this.driveLimitBytes,
    required this.pending,
    this.driveError,
  });

  final int localBytes;
  final int? driveUsageBytes;
  final int? driveLimitBytes;
  final SyncPendingCounts pending;
  final String? driveError;

  bool get driveAvailable =>
      driveError == null && driveUsageBytes != null;

  @Deprecated('Use pending.mediaItems')
  int get unsyncedMediaCount => pending.mediaItems;
}

class StorageMetricsService {
  StorageMetricsService(
    this._googleSignIn,
    this._pendingService,
  );

  final GoogleSignIn _googleSignIn;
  final SyncPendingService _pendingService;

  Future<StorageMetricsSnapshot> load({
    bool fetchDriveQuota = true,
  }) async {
    final localBytes = await _computeLocalAppBytes();
    final pending = await _pendingService.load();

    if (!fetchDriveQuota) {
      return StorageMetricsSnapshot(
        localBytes: localBytes,
        pending: pending,
      );
    }

    final googleAccount = await googleSignInSilently(_googleSignIn);
    if (googleAccount == null) {
      return StorageMetricsSnapshot(
        localBytes: localBytes,
        pending: pending,
      );
    }

    try {
      final drive = GoogleDriveService(_googleSignIn);
      final quota = await drive.fetchStorageQuota();
      return StorageMetricsSnapshot(
        localBytes: localBytes,
        driveUsageBytes: quota.usageBytes,
        driveLimitBytes: quota.limitBytes,
        pending: pending,
      );
    } catch (e) {
      return StorageMetricsSnapshot(
        localBytes: localBytes,
        pending: pending,
        driveError: e.toString(),
      );
    }
  }

  Future<int> _computeLocalAppBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!dir.existsSync()) return 0;
      return _directorySize(dir);
    } catch (_) {
      return 0;
    }
  }

  int _directorySize(Directory dir) {
    var total = 0;
    if (!dir.existsSync()) return 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }
}
