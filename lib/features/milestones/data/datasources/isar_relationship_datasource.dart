import 'package:isar/isar.dart';

import '../../../sync/schedule_cloud_sync.dart';
import '../models/local/relationship_collection.dart';

abstract class IsarRelationshipDataSource {
  Future<List<RelationshipCollection>> fetchAll();
  Future<List<RelationshipCollection>> fetchDeleted();

  Future<List<RelationshipCollection>> findInvolvingPerson(String personId);
  Future<void> put(RelationshipCollection row);
  Future<void> deleteById(String id, {bool softDelete = false});
  Future<void> deleteAllInvolvingPerson(String personId, {bool softDelete = false});
  Future<void> hardDelete(RelationshipCollection item);
}

class IsarRelationshipDataSourceImpl implements IsarRelationshipDataSource {
  IsarRelationshipDataSourceImpl(this._isar);

  final Isar _isar;

  Future<RelationshipCollection?> _findByIdAny(String id) =>
      _isar.relationshipCollections.filter().idEqualTo(id).findFirst();

  @override
  Future<List<RelationshipCollection>> fetchAll() =>
      _isar.relationshipCollections.filter().isDeletedEqualTo(false).findAll();

  @override
  Future<List<RelationshipCollection>> fetchDeleted() =>
      _isar.relationshipCollections.filter().isDeletedEqualTo(true).findAll();

  @override
  Future<List<RelationshipCollection>> findInvolvingPerson(
    String personId,
  ) async {
    final pid = personId.trim();
    if (pid.isEmpty) return const [];
    final asSubject = await _isar.relationshipCollections
        .filter()
        .isDeletedEqualTo(false)
        .personIdEqualTo(pid)
        .findAll();
    final asRelated = await _isar.relationshipCollections
        .filter()
        .isDeletedEqualTo(false)
        .relatedPersonIdEqualTo(pid)
        .findAll();
    final byKey = <String, RelationshipCollection>{};
    for (final r in asSubject) {
      byKey[r.id] = r;
    }
    for (final r in asRelated) {
      byKey[r.id] = r;
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        final ca = a.isCurrent == b.isCurrent ? 0 : (a.isCurrent ? -1 : 1);
        if (ca != 0) return ca;
        final sa = a.startDate;
        final sb = b.startDate;
        if (sa != null && sb != null) return sb.compareTo(sa);
        return a.relationshipType.compareTo(b.relationshipType);
      });
    return list;
  }

  @override
  Future<void> put(RelationshipCollection row) async {
    await _isar.writeTxn(() async {
      final existing = await _findByIdAny(row.id);
      if (existing != null) {
        row.isarId = existing.isarId;
        row.supabaseId ??= existing.supabaseId;
      }
      row.isSynced = false;
      await _isar.relationshipCollections.put(row);
    });
    scheduleCloudDataSync();
  }

  @override
  Future<void> hardDelete(RelationshipCollection item) async {
    await _isar.writeTxn(() async {
      await _isar.relationshipCollections.delete(item.isarId);
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
      await _isar.writeTxn(() => _isar.relationshipCollections.put(existing));
      scheduleCloudDataSync();
      return;
    }
    await hardDelete(existing);
  }

  @override
  Future<void> deleteAllInvolvingPerson(
    String personId, {
    bool softDelete = false,
  }) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    final rows = await _isar.relationshipCollections.where().findAll();
    await _isar.writeTxn(() async {
      for (final r in rows) {
        if (r.personId != pid && r.relatedPersonId != pid) continue;
        if (softDelete) {
          r
            ..isDeleted = true
            ..isSynced = false;
          await _isar.relationshipCollections.put(r);
        } else {
          await _isar.relationshipCollections.delete(r.isarId);
        }
      }
    });
    if (softDelete) scheduleCloudDataSync();
  }
}
