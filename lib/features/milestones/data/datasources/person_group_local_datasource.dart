import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/default_contact_groups.dart';
import '../models/local/group_collection.dart';
import '../models/local/person_collection.dart';
import '../models/local/person_group_link_collection.dart';
import 'isar_person_datasource.dart';

abstract class PersonGroupLocalDataSource {
  Future<void> ensureSeededAndMigrateLegacy(IsarPersonDataSource personDs);

  Future<List<PersonGroupLinkCollection>> fetchAllLinks();

  Future<List<GroupCollection>> fetchAllGroupsOrdered();

  /// Crea un grupo personalizado o devuelve el id si ya existe el mismo nombre (sin distinguir mayúsculas).
  Future<String> createCustomGroup(String name);

  Future<void> replacePersonMemberships(String personId, List<String> groupIds);

  Future<List<String>> groupIdsForPerson(String personId);

  Future<Map<String, List<String>>> buildPersonIdToGroupIds();

  Future<void> removeAllMembershipsForPerson(String personId);

  /// Import / backup: upsert grupo por [GroupCollection.id].
  Future<void> upsertGroup(GroupCollection row);

  /// Import / backup: crea o actualiza enlace persona–grupo.
  Future<void> putPersonGroupLinkForImport(String personId, String groupId);
}

class PersonGroupLocalDataSourceImpl implements PersonGroupLocalDataSource {
  PersonGroupLocalDataSourceImpl(this._isar);

  final Isar _isar;

  static String linkKeyOf(String personId, String groupId) =>
      '$personId|$groupId';

  @override
  Future<void> ensureSeededAndMigrateLegacy(
    IsarPersonDataSource personDs,
  ) async {
    await _isar.writeTxn(() async {
      final existingGroups = await _isar.groupCollections.where().findAll();
      final haveGroupIds =
          existingGroups.map((g) => g.id.toLowerCase()).toSet();

      for (final s in kDefaultContactGroupSeeds) {
        if (haveGroupIds.contains(s.id.toLowerCase())) continue;
        final row = GroupCollection()
          ..id = s.id
          ..name = s.name
          ..builtIn = true;
        await _isar.groupCollections.put(row);
        haveGroupIds.add(s.id.toLowerCase());
      }
    });

    final people = await personDs.fetchAll();
    final allGroups = await _isar.groupCollections.where().findAll();
    final allLinks = await _isar.personGroupLinkCollections.where().findAll();
    final linkKeys = allLinks.map((l) => l.linkKey).toSet();

    final byNameLower = <String, GroupCollection>{};
    for (final g in allGroups) {
      byNameLower[g.name.trim().toLowerCase()] = g;
    }

    final newGroups = <GroupCollection>[];
    final newLinks = <PersonGroupLinkCollection>[];
    final migratedPeople = <PersonCollection>[];

    for (final p in people) {
      final legacy = p.group.trim();
      if (legacy.isEmpty) continue;

      final key = legacy.toLowerCase();
      GroupCollection? target = byNameLower[key];
      if (target == null) {
        final id = const Uuid().v4();
        target = GroupCollection()
          ..id = id
          ..name = legacy
          ..builtIn = false;
        newGroups.add(target);
        byNameLower[key] = target;
      }

      final lk = linkKeyOf(p.id, target.id);
      if (!linkKeys.contains(lk)) {
        newLinks.add(
          PersonGroupLinkCollection()
            ..linkKey = lk
            ..personId = p.id
            ..groupId = target.id,
        );
        linkKeys.add(lk);
      }

      p.group = '';
      migratedPeople.add(p);
    }

    if (newGroups.isEmpty && newLinks.isEmpty && migratedPeople.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      for (final g in newGroups) {
        await _isar.groupCollections.put(g);
      }
      for (final l in newLinks) {
        await _isar.personGroupLinkCollections.put(l);
      }
      for (final p in migratedPeople) {
        await _isar.personCollections.put(p);
      }
    });
  }

  @override
  Future<List<PersonGroupLinkCollection>> fetchAllLinks() async =>
      _isar.personGroupLinkCollections.where().findAll();

  @override
  Future<List<GroupCollection>> fetchAllGroupsOrdered() async {
    final all = await _isar.groupCollections.where().findAll();
    all.sort((a, b) {
      final ca = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (ca != 0) return ca;
      return a.id.compareTo(b.id);
    });
    return all;
  }

  @override
  Future<String> createCustomGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nombre de grupo vacío');
    }
    final key = trimmed.toLowerCase();
    final all = await _isar.groupCollections.where().findAll();
    for (final g in all) {
      if (g.name.trim().toLowerCase() == key) return g.id;
    }
    final id = const Uuid().v4();
    final row = GroupCollection()
      ..id = id
      ..name = trimmed
      ..builtIn = false;
    await _isar.writeTxn(() => _isar.groupCollections.put(row));
    return id;
  }

  @override
  Future<void> replacePersonMemberships(
    String personId,
    List<String> groupIds,
  ) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    final wanted = <String>{
      for (final g in groupIds)
        if (g.trim().isNotEmpty) g.trim(),
    };

    await _isar.writeTxn(() async {
      final links = await _isar.personGroupLinkCollections.where().findAll();
      for (final l in links) {
        if (l.personId != pid) continue;
        await _isar.personGroupLinkCollections.delete(l.isarId);
      }
      for (final gid in wanted) {
        await _isar.personGroupLinkCollections.put(
          PersonGroupLinkCollection()
            ..linkKey = linkKeyOf(pid, gid)
            ..personId = pid
            ..groupId = gid,
        );
      }
    });
  }

  @override
  Future<List<String>> groupIdsForPerson(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return const [];
    final links = await _isar.personGroupLinkCollections.where().findAll();
    return links
        .where((l) => l.personId == pid)
        .map((l) => l.groupId)
        .toList();
  }

  @override
  Future<Map<String, List<String>>> buildPersonIdToGroupIds() async {
    final links = await _isar.personGroupLinkCollections.where().findAll();
    final map = <String, List<String>>{};
    for (final l in links) {
      map.putIfAbsent(l.personId, () => <String>[]).add(l.groupId);
    }
    return map;
  }

  @override
  Future<void> removeAllMembershipsForPerson(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    await _isar.writeTxn(() async {
      final links = await _isar.personGroupLinkCollections.where().findAll();
      for (final l in links) {
        if (l.personId != pid) continue;
        await _isar.personGroupLinkCollections.delete(l.isarId);
      }
    });
  }

  @override
  Future<void> upsertGroup(GroupCollection row) async {
    await _isar.writeTxn(() async {
      final all = await _isar.groupCollections.where().findAll();
      final existing = all.where((g) => g.id == row.id).firstOrNull;
      if (existing != null) row.isarId = existing.isarId;
      await _isar.groupCollections.put(row);
    });
  }

  @override
  Future<void> putPersonGroupLinkForImport(String personId, String groupId) async {
    final pid = personId.trim();
    final gid = groupId.trim();
    if (pid.isEmpty || gid.isEmpty) return;
    final lk = linkKeyOf(pid, gid);
    await _isar.writeTxn(() async {
      final existing = await _isar.personGroupLinkCollections
          .filter()
          .linkKeyEqualTo(lk)
          .findFirst();
      final row = existing ?? PersonGroupLinkCollection();
      row
        ..linkKey = lk
        ..personId = pid
        ..groupId = gid;
      await _isar.personGroupLinkCollections.put(row);
    });
  }
}
