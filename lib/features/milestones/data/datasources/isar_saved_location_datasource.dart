import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/exceptions/duplicate_saved_location_name_exception.dart';
import '../models/local/saved_location_collection.dart';

abstract class IsarSavedLocationDataSource {
  Future<List<SavedLocationCollection>> fetchAll();
  Future<SavedLocationCollection?> fetchById(Id isarId);
  Future<SavedLocationCollection> upsert(SavedLocationCollection c);
  Future<void> deleteById(Id isarId);
}

class IsarSavedLocationDataSourceImpl implements IsarSavedLocationDataSource {
  IsarSavedLocationDataSourceImpl(this._isar);

  final Isar _isar;

  @override
  Future<List<SavedLocationCollection>> fetchAll() async {
    final rows = await _isar.savedLocationCollections.where().findAll();
    rows.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return rows;
  }

  @override
  Future<SavedLocationCollection?> fetchById(Id isarId) =>
      _isar.savedLocationCollections.get(isarId);

  @override
  Future<SavedLocationCollection> upsert(SavedLocationCollection c) async {
    final trimmedName = c.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('El nombre del lugar no puede estar vacío.');
    }

    await _isar.writeTxn(() async {
      final all = await _isar.savedLocationCollections.where().findAll();
      for (final existing in all) {
        if (existing.isarId != c.isarId &&
            existing.name.trim() == trimmedName) {
          throw DuplicateSavedLocationNameException(trimmedName);
        }
      }

      if (c.isarId != Isar.autoIncrement) {
        final existing = await _isar.savedLocationCollections.get(c.isarId);
        if (existing != null && c.clientId.trim().isEmpty) {
          c.clientId = existing.clientId;
        }
      }
      if (c.clientId.trim().isEmpty) {
        c.clientId = const Uuid().v4();
      }
      c.name = trimmedName;
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
