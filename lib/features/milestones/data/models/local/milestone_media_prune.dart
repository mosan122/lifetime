import 'milestone_collection.dart';

/// Isar devuelve listas embebidas de longitud fija: hay que reasignar, no mutar in-place.
extension MilestoneMediaPrune on MilestoneCollection {
  /// Quita medios borrados localmente que nunca se subieron a Drive.
  void pruneDeletedWithoutDriveFile() {
    mediaItems = mediaItems
        .where(
          (e) =>
              !e.isDeleted ||
              (e.driveFileId != null && e.driveFileId!.trim().isNotEmpty),
        )
        .toList();
  }

  /// Quita medios marcados borrados cuyo [localPath] está en [paths].
  void pruneDeletedWithLocalPaths(Set<String> paths) {
    if (paths.isEmpty) return;
    mediaItems = mediaItems
        .where((e) => !(e.isDeleted && paths.contains(e.localPath)))
        .toList();
  }
}
