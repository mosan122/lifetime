import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/datasources/isar_milestone_datasource.dart';
import '../../domain/entities/media_item.dart';
import '../../features/milestones/data/models/local/media_item_embed.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import 'google_drive_service.dart';
import 'local_media_store.dart';

/// Carpetas `{milestoneId}` en Drive con al menos un archivo (p. ej. tras importar JSON).
class DriveMilestoneFolderProbeResult {
  const DriveMilestoneFolderProbeResult({
    this.matchingFolderIds = const [],
  });

  final List<String> matchingFolderIds;

  int get count => matchingFolderIds.length;
  bool get hasMatches => matchingFolderIds.isNotEmpty;
}

/// Resultado de enlazar medios en Drive con hitos locales.
class DriveMediaRestoreResult {
  const DriveMediaRestoreResult({
    this.milestonesTouched = 0,
    this.filesLinked = 0,
    this.filesDownloaded = 0,
  });

  final int milestonesTouched;
  final int filesLinked;
  final int filesDownloaded;

  bool get anyWork => milestonesTouched > 0 || filesLinked > 0;
}

/// Recorre `LifeTime_App/Media/.../{milestoneId}/` y enlaza archivos con hitos Isar.
class DriveMilestoneMediaRestore {
  DriveMilestoneMediaRestore(
    this._milestones,
    this._localMedia,
  );

  final IsarMilestoneDataSource _milestones;
  final LocalMediaStore _localMedia;

  static const _logName = 'DriveMilestoneMediaRestore';

  static final _milestoneIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Busca en `LifeTime_App/Media/.../` carpetas UUID que coincidan con [milestoneIds].
  Future<DriveMilestoneFolderProbeResult> probeFoldersForMilestoneIds(
    GoogleDriveService drive,
    Set<String> milestoneIds,
  ) async {
    if (milestoneIds.isEmpty) return const DriveMilestoneFolderProbeResult();

    final rootId = await drive.findExistingBackupFolder();
    if (rootId == null) return const DriveMilestoneFolderProbeResult();

    final mediaRootId = await drive.findFolderByName('Media', parentId: rootId);
    if (mediaRootId == null) return const DriveMilestoneFolderProbeResult();

    final found = <String>{};
    await _scanTreeForProbe(
      drive: drive,
      folderId: mediaRootId,
      milestoneIds: milestoneIds,
      onMatch: (id) => found.add(id),
    );
    return DriveMilestoneFolderProbeResult(
      matchingFolderIds: found.toList()..sort(),
    );
  }

  Future<DriveMediaRestoreResult> run(GoogleDriveService drive) async {
    final rootId = await drive.findExistingBackupFolder();
    if (rootId == null) {
      developer.log('Sin carpeta LifeTime en Drive', name: _logName);
      return const DriveMediaRestoreResult();
    }

    final mediaRootId = await drive.findFolderByName('Media', parentId: rootId);
    if (mediaRootId == null) {
      developer.log('Sin carpeta Media en Drive', name: _logName);
      return const DriveMediaRestoreResult();
    }

    final localMilestones = await _milestones.fetchAll();
    if (localMilestones.isEmpty) {
      return const DriveMediaRestoreResult();
    }
    final localById = {for (final m in localMilestones) m.id: m};

    var milestonesTouched = 0;
    var filesLinked = 0;
    var filesDownloaded = 0;

    await _scanTree(
      drive: drive,
      folderId: mediaRootId,
      localById: localById,
      onMilestoneFolder: (milestoneId, driveFolderId) async {
        final m = localById[milestoneId];
        if (m == null) return;

        final r = await _linkMilestoneFolder(
          drive: drive,
          milestone: m,
          driveFolderId: driveFolderId,
        );
        if (r.linked > 0) milestonesTouched++;
        filesLinked += r.linked;
        filesDownloaded += r.downloaded;
      },
    );

    if (filesLinked > 0) {
      developer.log(
        'Drive: $filesLinked archivo(s) enlazados en $milestonesTouched hito(s)',
        name: _logName,
      );
    }

    return DriveMediaRestoreResult(
      milestonesTouched: milestonesTouched,
      filesLinked: filesLinked,
      filesDownloaded: filesDownloaded,
    );
  }

  Future<void> _scanTreeForProbe({
    required GoogleDriveService drive,
    required String folderId,
    required Set<String> milestoneIds,
    required void Function(String milestoneId) onMatch,
  }) async {
    final listing = await drive.listFolderChildren(folderId);

    for (final folder in listing.folders) {
      if (_milestoneIdPattern.hasMatch(folder.name) &&
          milestoneIds.contains(folder.name)) {
        final children = await drive.listFolderChildren(folder.id);
        if (children.files.isNotEmpty) {
          onMatch(folder.name);
        }
        continue;
      }
      await _scanTreeForProbe(
        drive: drive,
        folderId: folder.id,
        milestoneIds: milestoneIds,
        onMatch: onMatch,
      );
    }
  }

  Future<void> _scanTree({
    required GoogleDriveService drive,
    required String folderId,
    required Map<String, MilestoneCollection> localById,
    required Future<void> Function(String milestoneId, String driveFolderId)
        onMilestoneFolder,
  }) async {
    final listing = await drive.listFolderChildren(folderId);

    for (final folder in listing.folders) {
      if (_milestoneIdPattern.hasMatch(folder.name) &&
          localById.containsKey(folder.name)) {
        await onMilestoneFolder(folder.name, folder.id);
        continue;
      }
      await _scanTree(
        drive: drive,
        folderId: folder.id,
        localById: localById,
        onMilestoneFolder: onMilestoneFolder,
      );
    }
  }

  Future<({int linked, int downloaded})> _linkMilestoneFolder({
    required GoogleDriveService drive,
    required MilestoneCollection milestone,
    required String driveFolderId,
  }) async {
    final listing = await drive.listFolderChildren(driveFolderId);
    if (listing.files.isEmpty) return (linked: 0, downloaded: 0);

    final raw = await _milestones.fetchCollectionById(milestone.id);
    if (raw == null) return (linked: 0, downloaded: 0);

    raw.driveFolderId = driveFolderId;
    final items = List<MediaItemEmbed>.from(raw.mediaItems);
    final knownDriveIds = items
        .map((e) => e.driveFileId?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    var linked = 0;
    var downloaded = 0;
    final folderPath = await _localMedia.ensureMilestoneFolder(
      date: raw.eventDate,
      milestoneId: raw.id,
    );

    for (final file in listing.files) {
      if (knownDriveIds.contains(file.id)) continue;

      final fileName = _safeFileName(file.name);
      if (fileName.isEmpty) continue;

      final mediaType = _mediaTypeFor(file);
      final localPath = folderPath != null
          ? p.join(folderPath, fileName)
          : '';

      var embed = _findExistingItem(items, file, localPath);
      if (embed != null) {
        embed
          ..driveFileId = file.id
          ..isSynced = true
          ..isDeleted = false;
        linked++;
        knownDriveIds.add(file.id);
        continue;
      }

      if (localPath.isNotEmpty && !File(localPath).existsSync()) {
        try {
          await drive.downloadFile(file.id, localPath);
          downloaded++;
        } catch (e) {
          developer.log(
            'No se pudo descargar ${file.name} para ${raw.id}: $e',
            name: _logName,
          );
          continue;
        }
      }

      var thumbPath = localPath;
      if (mediaType == MediaType.video && localPath.isNotEmpty) {
        final generated = await _localMedia.generateVideoThumbnail(
          date: raw.eventDate,
          milestoneId: raw.id,
          videoPath: localPath,
        );
        thumbPath = generated ?? localPath;
      }

      if (localPath.isEmpty) continue;

      // Enlazar por nombre si ya existe el archivo local (evita duplicar en la galería).
      final baseName = p.basename(localPath);
      MediaItemEmbed? sameBase;
      for (final e in items) {
        if (e.isDeleted) continue;
        if (p.basename(e.localPath) == baseName) {
          sameBase = e;
          break;
        }
      }
      if (sameBase != null) {
        sameBase
          ..driveFileId = file.id
          ..isSynced = true
          ..isDeleted = false;
        linked++;
        knownDriveIds.add(file.id);
        continue;
      }

      items.add(
        MediaItemEmbed()
          ..localPath = localPath
          ..thumbnailPath = thumbPath
          ..mediaType = mediaType
          ..driveFileId = file.id
          ..isSynced = true
          ..isDeleted = false,
      );
      linked++;
      knownDriveIds.add(file.id);
    }

    if (linked == 0) return (linked: 0, downloaded: downloaded);

    raw.mediaItems = items;
    _ensureGalleryCover(raw);
    if (raw.driveFileId == null || raw.driveFileId!.trim().isEmpty) {
      for (final e in items) {
        if (e.isDeleted || e.driveFileId == null) continue;
        if (e.mediaType == MediaType.image) {
          raw.driveFileId = e.driveFileId;
          break;
        }
      }
      if (raw.driveFileId == null) {
        for (final e in items) {
          if (!e.isDeleted && e.driveFileId != null) {
            raw.driveFileId = e.driveFileId;
            break;
          }
        }
      }
    }

    await _milestones.upsert(raw);
    return (linked: linked, downloaded: downloaded);
  }

  MediaItemEmbed? _findExistingItem(
    List<MediaItemEmbed> items,
    DriveListedFile file,
    String localPath,
  ) {
    final base = p.basename(file.name);
    for (final item in items) {
      if (item.isDeleted) continue;
      final existingId = item.driveFileId?.trim();
      if (existingId == file.id) return item;
      if (localPath.isNotEmpty && item.localPath == localPath) return item;
      if (p.basename(item.localPath) == base) return item;
    }
    return null;
  }

  void _ensureGalleryCover(MilestoneCollection m) {
    final n = m.mediaItems.where((e) => !e.isDeleted).length;
    if (n <= 0) {
      m.galleryCoverIndex = 0;
    } else if (m.galleryCoverIndex < 0 || m.galleryCoverIndex >= n) {
      m.galleryCoverIndex = 0;
    }
  }

  static String _safeFileName(String name) {
    final base = p.basename(name.trim());
    if (base.isEmpty || base == '.' || base == '..') return '';
    return base.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static MediaType _mediaTypeFor(DriveListedFile file) {
    final mime = file.mimeType.toLowerCase();
    if (mime.startsWith('video/')) return MediaType.video;
    final ext = p.extension(file.name).toLowerCase();
    if (ext == '.mp4' || ext == '.mov' || ext == '.mkv' || ext == '.webm') {
      return MediaType.video;
    }
    return MediaType.image;
  }
}
