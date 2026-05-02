import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'local_media_store.dart';

LocalMediaStore createLocalMediaStore() => LocalMediaStoreImpl();

class LocalMediaStoreImpl implements LocalMediaStore {
  Future<String> _folderPath(DateTime date, String milestoneId) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(
      dir.path,
      'media',
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
      milestoneId,
    );
  }

  Future<String> _legacyFolderPath(DateTime date, String milestoneId) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(
      dir.path,
      'LifeTime',
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
      milestoneId,
    );
  }

  Future<void> _migrateLegacyFolderIfNeeded(DateTime date, String milestoneId) async {
    try {
      final legacy = Directory(await _legacyFolderPath(date, milestoneId));
      if (!await legacy.exists()) return;

      final destPath = await _folderPath(date, milestoneId);
      final dest = Directory(destPath);
      if (await dest.exists()) return;

      await dest.parent.create(recursive: true);
      try {
        await legacy.rename(destPath);
      } on FileSystemException {
        await dest.create(recursive: true);
        await for (final entity in legacy.list(recursive: false)) {
          if (entity is File) {
            final name = p.basename(entity.path);
            await entity.copy(p.join(destPath, name));
          }
        }
        await legacy.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort migration.
      return;
    }
  }

  @override
  Future<void> deleteFolder(DateTime date, String milestoneId) async {
    final folderPath = await _folderPath(date, milestoneId);

    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) return;
      await folder.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup: missing/non-accessible folder should not fail delete.
      return;
    }
  }

  @override
  Future<String?> ensureMilestoneFolder({
    required DateTime date,
    required String milestoneId,
  }) async {
    try {
      await _migrateLegacyFolderIfNeeded(date, milestoneId);
      final destFolderPath = await _folderPath(date, milestoneId);
      final destFolder = Directory(destFolderPath);
      if (!await destFolder.exists()) {
        await destFolder.create(recursive: true);
      }
      return destFolderPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> moveFileToMilestoneFolder({
    required DateTime date,
    required String milestoneId,
    required String sourcePath,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final destFolderPath =
          await ensureMilestoneFolder(date: date, milestoneId: milestoneId);
      if (destFolderPath == null) return null;

      final fileName = p.basename(sourcePath);
      final destPath = p.join(destFolderPath, fileName);

      final destFile = File(destPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }

      // Try rename first (more efficient). If it fails (cross-device),
      // fall back to copy + delete.
      try {
        await sourceFile.rename(destPath);
        return destPath;
      } on FileSystemException {
        // fall through
      }

      await sourceFile.copy(destPath);
      await sourceFile.delete();
      return destPath;
    } catch (_) {
      // Best-effort: do not interrupt persistence flow.
      return null;
    }
  }

  @override
  Future<String?> generateVideoThumbnail({
    required DateTime date,
    required String milestoneId,
    required String videoPath,
  }) async {
    try {
      final destFolderPath =
          await ensureMilestoneFolder(date: date, milestoneId: milestoneId);
      if (destFolderPath == null) return null;

      final outPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: destFolderPath,
        imageFormat: ImageFormat.PNG,
        quality: 75,
      );

      return outPath;
    } catch (_) {
      return null;
    }
  }
}
