import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/isar_milestone_datasource.dart';
import 'premium_service.dart';

class CleanupService {
  static const _prefsKeyLastRun = 'cleanup_last_run_epoch_ms';

  final PremiumService _premium;
  final IsarMilestoneDataSource _milestones;

  CleanupService(this._premium, this._milestones);

  Future<void> runIfDue() async {
    if (!_premium.isPremium) return;

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_prefsKeyLastRun);
    final now = DateTime.now();

    if (last != null) {
      final lastRun = DateTime.fromMillisecondsSinceEpoch(last);
      if (now.difference(lastRun) < const Duration(days: 7)) {
        return;
      }
    }

    await runOnce();
    await prefs.setInt(_prefsKeyLastRun, now.millisecondsSinceEpoch);
  }

  Future<void> runOnce() async {
    if (!_premium.isPremium) return;

    final all = await _milestones.fetchAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 365));

    for (final m in all) {
      if (!m.eventDate.isBefore(cutoff)) continue;

      for (final item in m.mediaItems) {
        // Must be synced to cloud before removing originals.
        if (!item.isSynced) continue;
        if (item.driveFileId == null || item.driveFileId!.trim().isEmpty) {
          continue;
        }

        // Delete only the heavy original (localPath). Always keep thumbnailPath.
        final originalPath = item.localPath;
        if (originalPath.trim().isEmpty) continue;

        final originalFile = File(originalPath);
        if (!await originalFile.exists()) continue;

        // If for images thumbnailPath == localPath, we must NOT delete it.
        // (We'd lose the thumbnail as well.)
        if (item.thumbnailPath.trim().isNotEmpty &&
            item.thumbnailPath == item.localPath) {
          continue;
        }

        try {
          await originalFile.delete();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }
}

