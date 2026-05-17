import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/local/saved_location_collection.dart';

abstract class IsarSavedLocationDataSource {
  Future<List<SavedLocationCollection>> fetchAll();
  Future<SavedLocationCollection?> fetchById(Id isarId);
  Future<SavedLocationCollection> upsert(SavedLocationCollection c);
  Future<void> deleteById(Id isarId);
}

class IsarSavedLocationDataSourceImpl implements IsarSavedLocationDataSource {
  final Isar _isar;
  IsarSavedLocationDataSourceImpl(this._isar);

  @override
  Future<List<SavedLocationCollection>> fetchAll() =>
      _isar.savedLocationCollections.where().sortByName().findAll();

  @override
  Future<SavedLocationCollection?> fetchById(Id isarId) =>
      _isar.savedLocationCollections.get(isarId);

  @override
  Future<SavedLocationCollection> upsert(SavedLocationCollection c) async {
    if (c.clientId.trim().isEmpty) {
      c.clientId = const Uuid().v4();
    }
    await _isar.writeTxn(() async {
      await _isar.savedLocationCollections.put(c);
    });
    return c;
  }

  @override
  Future<void> deleteById(Id isarId) async {
    await _isar.writeTxn(() async {
      await _isar.savedLocationCollections.delete(isarId);
    });
  }
}

