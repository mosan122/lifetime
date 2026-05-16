import 'package:isar/isar.dart';

import 'package:lifetime/features/milestones/data/models/local/person_collection.dart';
import 'package:lifetime/features/milestones/data/models/local/person_group_link_collection.dart';
import 'package:lifetime/features/sync/schedule_cloud_sync.dart';

abstract class IsarPersonDataSource {
  Future<PersonCollection?> fetchByName(String name);
  Future<PersonCollection?> fetchById(String id);
  Future<List<PersonCollection>> fetchByIds(List<String> ids);
  /// Persona vinculada a la cuenta LifeTime (`linkedUserId` = id Supabase).
  Future<PersonCollection?> fetchByLinkedUserId(String linkedUserId);
  Future<List<PersonCollection>> fetchAll();
  Future<List<PersonCollection>> fetchDeleted();
  Future<PersonCollection> upsert(PersonCollection c);
  Future<void> deleteById(String id, {bool softDelete = false});
  Future<void> hardDelete(PersonCollection item);
}

class IsarPersonDataSourceImpl implements IsarPersonDataSource {
  IsarPersonDataSourceImpl(this._isar);

  final Isar _isar;

  Future<PersonCollection?> _findByIdAny(String id) async {
    final all = await _isar.personCollections.where().findAll();
    return all.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<PersonCollection?> fetchByName(String name) async {
    final all = await fetchAll();
    final needle = name.trim().toLowerCase();
    return all
        .where((p) => p.name.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  @override
  Future<PersonCollection?> fetchById(String id) async {
    final item = await _findByIdAny(id);
    if (item == null || item.isDeleted) return null;
    return item;
  }

  @override
  Future<List<PersonCollection>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final all = await fetchAll();
    final wanted = ids.toSet();
    return all.where((p) => wanted.contains(p.id)).toList();
  }

  @override
  Future<PersonCollection?> fetchByLinkedUserId(String linkedUserId) async {
    final v = linkedUserId.trim();
    if (v.isEmpty) return null;
    final all = await fetchAll();
    return all.where((p) => (p.linkedUserId ?? '').trim() == v).firstOrNull;
  }

  @override
  Future<List<PersonCollection>> fetchAll() async {
    final rows = await _isar.personCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    return rows;
  }

  @override
  Future<List<PersonCollection>> fetchDeleted() =>
      _isar.personCollections.filter().isDeletedEqualTo(true).findAll();

  @override
  Future<PersonCollection> upsert(PersonCollection c) async {
    await _isar.writeTxn(() async {
      final existing = await _findByIdAny(c.id);
      if (existing != null) {
        c.isarId = existing.isarId;
        c.supabaseId ??= existing.supabaseId;
      }
      c.isSynced = false;
      await _isar.personCollections.put(c);
    });
    scheduleCloudDataSync();
    return c;
  }

  @override
  Future<void> hardDelete(PersonCollection item) async {
    await _isar.writeTxn(() async {
      final links = await _isar.personGroupLinkCollections.where().findAll();
      for (final l in links) {
        if (l.personId == item.id) {
          await _isar.personGroupLinkCollections.delete(l.isarId);
        }
      }
      await _isar.personCollections.delete(item.isarId);
    });
  }

  @override
  Future<void> deleteById(String id, {bool softDelete = false}) async {
    final existing = await _findByIdAny(id);
    if (existing == null) return;
    if (softDelete) {
      existing
        ..isDeleted = true
        ..isSynced = false;
      await _isar.writeTxn(() => _isar.personCollections.put(existing));
      scheduleCloudDataSync();
      return;
    }
    await hardDelete(existing);
  }
}
