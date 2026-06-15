import 'dart:io';

import '../../data/datasources/isar_milestone_datasource.dart';
import 'premium_service.dart';

class SpaceCleanupService {
  final PremiumService _premium;
  final IsarMilestoneDataSource _milestones;

  SpaceCleanupService(this._premium, this._milestones);

  Future<void> runCleanup() async {
    if (!_premium.isPremium) return;

    final all = await _milestones.fetchAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 365));

    for (final m in all) {
      // Requisito: createdAt de hace más de 365 días.
      if (!m.createdAt.isBefore(cutoff)) continue;

      for (final item in m.mediaItems) {
        // Filtro crítico
        if (!item.isSynced) continue;
        if (item.driveFileId == null || item.driveFileId!.trim().isEmpty) continue;

        final originalPath = item.localPath.trim();
        if (originalPath.isEmpty) continue;

        // IMPORTANTE: no borrar el archivo apuntado por thumbnailPath.
        final thumbPath = item.thumbnailPath.trim();
        if (thumbPath.isNotEmpty && thumbPath == originalPath) {
          continue;
        }

        final f = File(originalPath);
        if (!await f.exists()) continue;

        try {
          await f.delete();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }
}

