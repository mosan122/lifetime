import 'local_media_store.dart';

LocalMediaStore createLocalMediaStore() => _WebLocalMediaStore();

class _WebLocalMediaStore implements LocalMediaStore {
  @override
  Future<void> deleteFolder(DateTime date, String milestoneId) async {}

  @override
  Future<String?> ensureMilestoneFolder({
    required DateTime date,
    required String milestoneId,
  }) async =>
      null;

  @override
  Future<String?> moveFileToMilestoneFolder({
    required DateTime date,
    required String milestoneId,
    required String sourcePath,
  }) async =>
      null;

  @override
  Future<String?> generateVideoThumbnail({
    required DateTime date,
    required String milestoneId,
    required String videoPath,
  }) async =>
      null;
}
