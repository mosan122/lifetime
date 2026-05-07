// lib/data/datasources/isar_milestone_datasource.dart
import 'package:isar/isar.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

abstract class IsarMilestoneDataSource {
  Future<List<MilestoneCollection>> fetchAll();
  Future<MilestoneCollection?> fetchById(String id);
  Future<MilestoneCollection> upsert(MilestoneCollection c);
  Future<void> deleteById(String id);
  Future<void> markSynced(String id);
  /// Returns most recent unique saved locations.
  Future<List<MilestoneLocationDataEmbed>> fetchRecentLocations({
    int limit = 8,
  });
  Future<void> markMediaItemSynced({
    required String milestoneId,
    required String localPath,
    required String driveFileId,
  });
  Future<void> setDriveFolderId({
    required String milestoneId,
    required String driveFolderId,
  });
  Future<List<MilestoneCollection>> fetchPending();
}

class IsarMilestoneDataSourceImpl implements IsarMilestoneDataSource {
  final Isar _isar;
  IsarMilestoneDataSourceImpl(this._isar);

  @override
  Future<List<MilestoneCollection>> fetchAll() =>
      _isar.milestoneCollections
          .where()
          .sortByEventDateDesc()
          .findAll();

  @override
  Future<MilestoneCollection?> fetchById(String id) =>
      _isar.milestoneCollections
          .filter()
          .idEqualTo(id)
          .findFirst();

  @override
  Future<MilestoneCollection> upsert(MilestoneCollection c) async {
    await _isar.writeTxn(() async {
      // Preserve the existing isarId so the unique index is not violated.
      final existing = await _isar.milestoneCollections
          .filter()
          .idEqualTo(c.id)
          .findFirst();
      if (existing != null) {
        c.isarId = existing.isarId;
      }
      await _isar.milestoneCollections.put(c);
    });
    return c;
  }

  @override
  Future<void> deleteById(String id) async {
    final item = await fetchById(id);
    if (item == null) return;
    await _isar.writeTxn(
      () => _isar.milestoneCollections.delete(item.isarId),
    );
  }

  @override
  Future<List<MilestoneLocationDataEmbed>> fetchRecentLocations({
    int limit = 8,
  }) async {
    final items = await _isar.milestoneCollections
        .where()
        .sortByCreatedAtDesc()
        .findAll();

    final seen = <String>{};
    final out = <MilestoneLocationDataEmbed>[];

    String keyOf(MilestoneLocationDataEmbed l) {
      final name = (l.name ?? '').trim().toLowerCase();
      final lat = l.latitude;
      final lon = l.longitude;
      final latKey = lat == null ? '' : lat.toStringAsFixed(5);
      final lonKey = lon == null ? '' : lon.toStringAsFixed(5);
      return '$name|$latKey|$lonKey';
    }

    for (final m in items) {
      final loc = m.location ??
          (() {
            final name = m.locationName;
            final lat = m.latitude;
            final lon = m.longitude;
            if ((name == null || name.trim().isEmpty) &&
                lat == null &&
                lon == null) {
              return null;
            }
            return MilestoneLocationDataEmbed()
              ..name = name
              ..latitude = lat
              ..longitude = lon;
          })();
      if (loc == null) continue;
      final k = keyOf(loc);
      if (k.trim().isEmpty) continue;
      if (!seen.add(k)) continue;
      out.add(loc);
      if (out.length >= limit.clamp(1, 20)) break;
    }
    return out;
  }

  @override
  Future<void> markSynced(String id) async {
    final item = await fetchById(id);
    if (item == null) return;
    item.syncStatus = SyncStatus.synced;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<void> markMediaItemSynced({
    required String milestoneId,
    required String localPath,
    required String driveFileId,
  }) async {
    final item = await fetchById(milestoneId);
    if (item == null) return;
    final idx = item.mediaItems.indexWhere((m) => m.localPath == localPath);
    if (idx < 0) return;
    item.mediaItems[idx]
      ..isSynced = true
      ..driveFileId = driveFileId;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<void> setDriveFolderId({
    required String milestoneId,
    required String driveFolderId,
  }) async {
    final item = await fetchById(milestoneId);
    if (item == null) return;
    item.driveFolderId = driveFolderId;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<List<MilestoneCollection>> fetchPending() =>
      _isar.milestoneCollections
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .findAll();
}
