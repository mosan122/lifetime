// test/data/datasources/isar_milestone_datasource_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

void main() {
  late Isar isar;
  late Directory tempDir;
  late IsarMilestoneDataSourceImpl datasource;

  MilestoneCollection makeCollection({
    String id = 'ms-1',
    String title = 'Test Hito',
    SyncStatus syncStatus = SyncStatus.pending,
  }) {
    return MilestoneCollection()
      ..id = id
      ..userId = 'user-1'
      ..title = title
      ..description = 'Descripción de prueba'
      ..participants = ['Ana']
      ..eventDate = DateTime(2026, 4, 26)
      ..locationName = 'Madrid'
      ..latitude = 40.4168
      ..longitude = -3.7038
      ..category = 'general'
      ..isPublic = false
      ..createdAt = DateTime(2026, 4, 26, 10)
      ..syncStatus = syncStatus
      ..media = [];
  }

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('isar_test_${DateTime.now().microsecondsSinceEpoch}');
    isar = await Isar.open(
      [MilestoneCollectionSchema],
      directory: tempDir.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = IsarMilestoneDataSourceImpl(isar);
  });

  tearDown(() async {
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  group('upsert + fetchAll', () {
    test('upsert returns the collection and fetchAll contains it', () async {
      final collection = makeCollection();

      await datasource.upsert(collection);
      final all = await datasource.fetchAll();

      expect(all, hasLength(1));
      expect(all.first.id, equals('ms-1'));
      expect(all.first.title, equals('Test Hito'));
    });

    test('fetchAll returns items ordered by eventDate descending', () async {
      await datasource.upsert(makeCollection(
          id: 'ms-older', title: 'Older')
        ..eventDate = DateTime(2025, 1, 1));
      await datasource.upsert(makeCollection(
          id: 'ms-newer', title: 'Newer')
        ..eventDate = DateTime(2026, 6, 1));

      final all = await datasource.fetchAll();

      expect(all.first.id, equals('ms-newer'));
      expect(all.last.id, equals('ms-older'));
    });

    test('upserting the same id updates in place', () async {
      final original = makeCollection(title: 'Original');
      await datasource.upsert(original);

      final updated = makeCollection(title: 'Updated');
      await datasource.upsert(updated);

      final all = await datasource.fetchAll();
      expect(all, hasLength(1));
      expect(all.first.title, equals('Updated'));
    });
  });

  group('fetchById', () {
    test('returns collection when id matches', () async {
      await datasource.upsert(makeCollection(id: 'ms-abc'));

      final result = await datasource.fetchById('ms-abc');

      expect(result, isNotNull);
      expect(result!.id, equals('ms-abc'));
    });

    test('returns null when id not found', () async {
      final result = await datasource.fetchById('nonexistent');
      expect(result, isNull);
    });
  });

  group('deleteById', () {
    test('removes the item from the store', () async {
      await datasource.upsert(makeCollection());

      await datasource.deleteById('ms-1');

      final all = await datasource.fetchAll();
      expect(all, isEmpty);
    });

    test('is idempotent when id does not exist', () async {
      await expectLater(
        datasource.deleteById('nonexistent'),
        completes,
      );
    });
  });

  group('markSynced', () {
    test('updates syncStatus to synced without changing other fields', () async {
      await datasource.upsert(makeCollection(syncStatus: SyncStatus.pending));

      await datasource.markSynced('ms-1');

      final item = await datasource.fetchById('ms-1');
      expect(item, isNotNull);
      expect(item!.syncStatus, equals(SyncStatus.synced));
      expect(item.title, equals('Test Hito'));
    });

    test('is idempotent when id does not exist', () async {
      await expectLater(datasource.markSynced('nonexistent'), completes);
    });
  });

  group('fetchPending', () {
    test('returns only pending items', () async {
      await datasource.upsert(makeCollection(
          id: 'ms-synced', syncStatus: SyncStatus.synced));
      await datasource.upsert(makeCollection(
          id: 'ms-pending', syncStatus: SyncStatus.pending));

      final pending = await datasource.fetchPending();

      expect(pending, hasLength(1));
      expect(pending.first.id, equals('ms-pending'));
    });

    test('returns empty list when no pending items', () async {
      await datasource.upsert(makeCollection(syncStatus: SyncStatus.synced));

      final pending = await datasource.fetchPending();

      expect(pending, isEmpty);
    });
  });
}
