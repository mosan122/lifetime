// lib/data/datasources/isar_milestone_datasource.dart
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

abstract class IsarMilestoneDataSource {
  Future<List<MilestoneCollection>> fetchAll();
  Future<MilestoneCollection?> fetchById(String id);

  /// Hito local por id, incluidos borrados lógicamente (sync / medios).
  Future<MilestoneCollection?> fetchCollectionById(String id);
  Future<MilestoneCollection> upsert(MilestoneCollection c);
  Future<void> deleteById(String id, {bool softDelete = false});
  Future<List<MilestoneCollection>> fetchDeleted();
  Future<void> hardDelete(MilestoneCollection item);
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
  Future<List<MilestoneCollection>> fetchUnsynced();

  Future<void> renameLocationForCoordinates({
    required double latitude,
    required double longitude,
    required String newName,
  });

  Future<void> syncSavedLocationToMilestones({
    required int savedLocationId,
    required String name,
    required String? city,
    required String? country,
    required double? latitude,
    required double? longitude,
  });

  /// Quita [personId] de participantes y protagonistas en todos los hitos locales.
  Future<void> removePersonFromAllMilestones(String personId);

  /// Hitos donde [personId] figura en participantes o protagonistas.
  Future<int> countMilestonesContainingPerson(String personId);

  /// Recuento de hitos por persona (participante o protagonista).
  Future<Map<String, int>> buildPersonMilestoneParticipationCounts();

  /// Hitos activos que usan el lugar favorito [savedLocationId].
  Future<int> countMilestonesUsingSavedLocation(int savedLocationId);

  /// Medios locales en hitos activos con [MediaItemEmbed.isSynced] == false.
  Future<int> countUnsyncedMediaItems();

  /// Hitos activos con metadatos pendientes de Supabase ([isSynced] == false).
  Future<int> countUnsyncedMilestones();
}

class IsarMilestoneDataSourceImpl implements IsarMilestoneDataSource {
  final Isar _isar;
  IsarMilestoneDataSourceImpl(this._isar);

  @override
  Future<List<MilestoneCollection>> fetchAll() =>
      _isar.milestoneCollections
          .filter()
          .isDeletedEqualTo(false)
          .sortByEventDateDesc()
          .findAll();

  Future<MilestoneCollection?> _findByIdAny(String id) =>
      _isar.milestoneCollections.filter().idEqualTo(id).findFirst();

  @override
  Future<MilestoneCollection?> fetchById(String id) async {
    final item = await _findByIdAny(id);
    if (item == null || item.isDeleted) return null;
    return item;
  }

  @override
  Future<MilestoneCollection?> fetchCollectionById(String id) =>
      _findByIdAny(id);

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
        if (existing.isDeleted) {
          return existing;
        }
      }
      await _isar.milestoneCollections.put(c);
    });
    return c;
  }

  @override
  Future<List<MilestoneCollection>> fetchDeleted() =>
      _isar.milestoneCollections.filter().isDeletedEqualTo(true).findAll();

  @override
  Future<void> hardDelete(MilestoneCollection item) async {
    await _isar.writeTxn(
      () => _isar.milestoneCollections.delete(item.isarId),
    );
  }

  @override
  Future<void> deleteById(String id, {bool softDelete = false}) async {
    final item = await _findByIdAny(id);
    if (item == null) return;
    if (softDelete) {
      item
        ..isDeleted = true
        ..isSynced = false
        ..syncStatus = SyncStatus.pending;
      await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
      return;
    }
    await hardDelete(item);
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
    item.isSynced = true;
    item.supabaseId ??= item.id;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<void> markMediaItemSynced({
    required String milestoneId,
    required String localPath,
    required String driveFileId,
  }) async {
    final item = await fetchCollectionById(milestoneId);
    if (item == null) return;
    var idx = item.mediaItems.indexWhere((m) => m.localPath == localPath);
    if (idx < 0) {
      final base = p.basename(localPath);
      idx = item.mediaItems.indexWhere(
        (m) => p.basename(m.localPath) == base,
      );
    }
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
          .isDeletedEqualTo(false)
          .syncStatusEqualTo(SyncStatus.pending)
          .findAll();

  @override
  Future<List<MilestoneCollection>> fetchUnsynced() =>
      _isar.milestoneCollections
          .filter()
          .isDeletedEqualTo(false)
          .isSyncedEqualTo(false)
          .findAll();

  @override
  Future<void> renameLocationForCoordinates({
    required double latitude,
    required double longitude,
    required String newName,
  }) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    final latKey = latitude.toStringAsFixed(5);
    final lonKey = longitude.toStringAsFixed(5);

    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final toUpdate = <MilestoneCollection>[];

    for (final m in all) {
      final loc = m.location;
      final lat = loc?.latitude ?? m.latitude;
      final lon = loc?.longitude ?? m.longitude;
      if (lat == null || lon == null) continue;
      if (lat.toStringAsFixed(5) != latKey) continue;
      if (lon.toStringAsFixed(5) != lonKey) continue;

      final currentName = (loc?.name ?? m.locationName ?? '').trim();
      if (currentName.isEmpty) continue;
      if (currentName == name) continue;

      (m.location ??= MilestoneLocationDataEmbed())
        ..name = name
        ..latitude = lat
        ..longitude = lon;
      m.locationName = name;
      toUpdate.add(m);
    }

    if (toUpdate.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.milestoneCollections.putAll(toUpdate);
    });
  }

  @override
  Future<void> syncSavedLocationToMilestones({
    required int savedLocationId,
    required String name,
    required String? city,
    required String? country,
    required double? latitude,
    required double? longitude,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final toUpdate = <MilestoneCollection>[];

    for (final m in all) {
      if (m.savedLocationId != savedLocationId) continue;

      (m.location ??= MilestoneLocationDataEmbed())
        ..name = n
        ..city = (city ?? '').trim().isEmpty ? null : city!.trim()
        ..country = (country ?? '').trim().isEmpty ? null : country!.trim()
        ..latitude = latitude
        ..longitude = longitude;

      m.locationName = n;
      m.latitude = latitude;
      m.longitude = longitude;
      toUpdate.add(m);
    }

    if (toUpdate.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.milestoneCollections.putAll(toUpdate);
    });
  }

  @override
  Future<void> removePersonFromAllMilestones(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final toUpdate = <MilestoneCollection>[];
    for (final m in all) {
      final hadParticipant = m.participants.contains(pid);
      final hadProtagonist = m.protagonists.contains(pid);
      if (!hadParticipant && !hadProtagonist) continue;
      m.participants = m.participants.where((id) => id != pid).toList();
      m.protagonists = m.protagonists.where((id) => id != pid).toList();
      if (m.syncStatus == SyncStatus.synced || m.isSynced) {
        m.syncStatus = SyncStatus.pending;
        m.isSynced = false;
      }
      toUpdate.add(m);
    }
    if (toUpdate.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.milestoneCollections.putAll(toUpdate);
    });
  }

  @override
  Future<int> countMilestonesContainingPerson(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return 0;
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    var n = 0;
    for (final m in all) {
      if (m.isDeleted) continue;
      if (m.participants.contains(pid) || m.protagonists.contains(pid)) {
        n++;
      }
    }
    return n;
  }

  @override
  Future<Map<String, int>> buildPersonMilestoneParticipationCounts() async {
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final counts = <String, int>{};
    for (final m in all) {
      final seen = <String>{};
      for (final id in [...m.participants, ...m.protagonists]) {
        final pid = id.trim();
        if (pid.isEmpty || !seen.add(pid)) continue;
        counts[pid] = (counts[pid] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<int> countMilestonesUsingSavedLocation(int savedLocationId) async {
    if (savedLocationId <= 0) return 0;
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    var n = 0;
    for (final m in all) {
      if (m.savedLocationId == savedLocationId) n++;
    }
    return n;
  }

  @override
  Future<int> countUnsyncedMediaItems() async {
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    var n = 0;
    for (final m in all) {
      for (final item in m.mediaItems) {
        if (!item.isDeleted && !item.isSynced) n++;
      }
    }
    return n;
  }

  @override
  Future<int> countUnsyncedMilestones() async {
    final all = await _isar.milestoneCollections
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    return all
        .where(
          (m) =>
              !m.isSynced ||
              m.supabaseId == null ||
              m.supabaseId!.trim().isEmpty,
        )
        .length;
  }
}
