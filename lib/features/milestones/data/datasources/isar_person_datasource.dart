import 'package:isar/isar.dart';

import 'package:lifetime/features/milestones/data/models/local/person_collection.dart';

abstract class IsarPersonDataSource {
  Future<PersonCollection?> fetchByName(String name);
  Future<PersonCollection?> fetchById(String id);
  Future<List<PersonCollection>> fetchByIds(List<String> ids);
  Future<List<PersonCollection>> fetchAll();
  Future<PersonCollection> upsert(PersonCollection c);
  Future<void> deleteById(String id);
}

class IsarPersonDataSourceImpl implements IsarPersonDataSource {
  final Isar _isar;

  IsarPersonDataSourceImpl(this._isar);

  @override
  Future<PersonCollection?> fetchByName(String name) async {
    // Avoid relying on generated `displayNameEqualTo` helpers (schema codegen
    // may be missing in this environment). Load and filter in memory.
    final all = await _isar.personCollections.where().findAll();
    final needle = name.trim().toLowerCase();
    return all
        .where((p) => p.name.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  @override
  Future<PersonCollection?> fetchById(String id) async {
    final all = await _isar.personCollections.where().findAll();
    return all.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<List<PersonCollection>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final all = await _isar.personCollections.where().findAll();
    final wanted = ids.toSet();
    return all.where((p) => wanted.contains(p.id)).toList();
  }

  @override
  Future<List<PersonCollection>> fetchAll() async =>
      _isar.personCollections.where().findAll();

  @override
  Future<PersonCollection> upsert(PersonCollection c) async {
    await _isar.writeTxn(() async {
      final all = await _isar.personCollections.where().findAll();
      final existing =
          all.where((p) => p.id == c.id).firstOrNull;
      if (existing != null) c.isarId = existing.isarId;
      await _isar.personCollections.put(c);
    });
    return c;
  }

  @override
  Future<void> deleteById(String id) async {
    final all = await _isar.personCollections.where().findAll();
    final existing = all.where((p) => p.id == id).firstOrNull;
    if (existing == null) return;
    await _isar.writeTxn(() => _isar.personCollections.delete(existing.isarId));
  }
}

