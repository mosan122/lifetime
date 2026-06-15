import 'package:isar/isar.dart';

import '../../../../core/constants/milestone_categories.dart';
import '../models/local/category_collection.dart';

abstract class IsarCategoryDataSource {
  Future<List<CategoryCollection>> fetchAll();
  Future<CategoryCollection?> fetchByCategoryId(String id);
  Future<CategoryCollection> upsert(CategoryCollection c);
  Future<void> deleteByCategoryId(String id);
  Future<void> ensureSeeded();
}

CategoryCollection _categoryCollectionFromSeed(MilestoneCategorySeed s) =>
    CategoryCollection()
      ..id = s.id
      ..name = s.name
      ..iconName = s.iconKey
      ..colorValue = s.colorArgb;

class IsarCategoryDataSourceImpl implements IsarCategoryDataSource {
  final Isar _isar;
  IsarCategoryDataSourceImpl(this._isar);

  @override
  Future<List<CategoryCollection>> fetchAll() =>
      _isar.categoryCollections.where().sortByName().findAll();

  @override
  Future<CategoryCollection?> fetchByCategoryId(String id) =>
      _isar.categoryCollections.filter().idEqualTo(id).findFirst();

  @override
  Future<CategoryCollection> upsert(CategoryCollection c) async {
    await _isar.writeTxn(() async {
      final existing = await fetchByCategoryId(c.id);
      if (existing != null) c.isarId = existing.isarId;
      await _isar.categoryCollections.put(c);
    });
    return c;
  }

  @override
  Future<void> deleteByCategoryId(String id) async {
    final existing = await fetchByCategoryId(id);
    if (existing == null) return;
    await _isar.writeTxn(() => _isar.categoryCollections.delete(existing.isarId));
  }

  @override
  Future<void> ensureSeeded() async {
    final existing = await _isar.categoryCollections.where().findAll();
    if (existing.isEmpty) {
      final seeds =
          kMilestoneCategorySeeds.map(_categoryCollectionFromSeed).toList();
      await _isar.writeTxn(() async {
        await _isar.categoryCollections.putAll(seeds);
      });
      return;
    }

    final have = existing.map((e) => e.id.toLowerCase()).toSet();
    final missing = kMilestoneCategorySeeds
        .where((s) => !have.contains(s.id.toLowerCase()))
        .map(_categoryCollectionFromSeed)
        .toList();
    if (missing.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.categoryCollections.putAll(missing);
    });
  }
}
