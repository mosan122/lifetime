abstract class LocalMediaStore {
  /// Deletes media/YYYY/MM/DD/{milestoneId}/ under app documents dir.
  /// Missing folder is treated as a no-op.
  Future<void> deleteFolder(DateTime date, String milestoneId);

  /// Ensures the milestone folder exists and returns its path.
  ///
  /// Returns null on platforms that don't support local file storage.
  Future<String?> ensureMilestoneFolder({
    required DateTime date,
    required String milestoneId,
  });

  /// Moves an already-selected local file into:
  /// media/YYYY/MM/DD/{milestoneId}/
  ///
  /// Best-effort: if the move fails (missing source, FS error, etc.) the
  /// error should not break the caller flow.
  ///
  /// Returns the destination path if the file ends up there, otherwise null.
  Future<String?> moveFileToMilestoneFolder({
    required DateTime date,
    required String milestoneId,
    required String sourcePath,
  });

  /// Generates a thumbnail image for [videoPath] and stores it under the
  /// milestone folder. Returns the thumbnail file path, or null if it fails.
  Future<String?> generateVideoThumbnail({
    required DateTime date,
    required String milestoneId,
    required String videoPath,
  });
}
