// lib/data/datasources/isar_milestone_datasource.dart
import 'package:isar/isar.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

abstract class IsarMilestoneDataSource {
  Future<List<MilestoneCollection>> fetchAll();
  Future<MilestoneCollection?> fetchById(String id);
  Future<MilestoneCollection> upsert(MilestoneCollection c);
  Future<void> deleteById(String id);
  Future<void> markSynced(String id);
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
  Future<void> markSynced(String id) async {
    final item = await fetchById(id);
    if (item == null) return;
    item.syncStatus = SyncStatus.synced;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<List<MilestoneCollection>> fetchPending() =>
      _isar.milestoneCollections
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .findAll();
}
