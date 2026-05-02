import 'package:isar/isar.dart';

import '../models/local/category_collection.dart';

abstract class IsarCategoryDataSource {
  Future<List<CategoryCollection>> fetchAll();
  Future<CategoryCollection?> fetchById(int id);
  Future<CategoryCollection?> fetchByName(String name);
  Future<CategoryCollection> upsert(CategoryCollection c);
  Future<void> deleteById(int id);
  Future<void> ensureSeeded();
}

class IsarCategoryDataSourceImpl implements IsarCategoryDataSource {
  final Isar _isar;
  IsarCategoryDataSourceImpl(this._isar);

  @override
  Future<List<CategoryCollection>> fetchAll() =>
      _isar.categoryCollections.where().sortByName().findAll();

  @override
  Future<CategoryCollection?> fetchById(int id) =>
      _isar.categoryCollections.get(id);

  @override
  Future<CategoryCollection?> fetchByName(String name) =>
      _isar.categoryCollections
          .filter()
          .nameEqualTo(name)
          .findFirst();

  @override
  Future<CategoryCollection> upsert(CategoryCollection c) async {
    await _isar.writeTxn(() async {
      // Preserve existing id for unique name updates.
      final existing = await fetchByName(c.name);
      if (existing != null) {
        c.id = existing.id;
        c.isSystem = existing.isSystem;
      }
      await _isar.categoryCollections.put(c);
    });
    return c;
  }

  @override
  Future<void> deleteById(int id) async {
    final existing = await fetchById(id);
    if (existing == null) return;
    if (existing.isSystem) return;
    await _isar.writeTxn(() => _isar.categoryCollections.delete(id));
  }

  @override
  Future<void> ensureSeeded() async {
    final count = await _isar.categoryCollections.count();
    if (count > 0) return;

    final seeds = <CategoryCollection>[
      _seed(name: 'General', iconName: 'category', colorValue: 0xFF9E9E9E),
      _seed(name: 'Cumpleaños', iconName: 'cake', colorValue: 0xFFFFC1CC),
      _seed(name: 'Boda', iconName: 'favorite', colorValue: 0xFFF48FB1),
      _seed(name: 'Nacimiento', iconName: 'child_care', colorValue: 0xFF4DB6AC),
      _seed(name: 'Especial', iconName: 'star', colorValue: 0xFFFFD54F),
    ];

    await _isar.writeTxn(() async {
      await _isar.categoryCollections.putAll(seeds);
    });
  }

  static CategoryCollection _seed({
    required String name,
    required String iconName,
    required int colorValue,
  }) {
    return CategoryCollection()
      ..name = name
      ..iconName = iconName
      ..colorValue = colorValue
      ..isSystem = true;
  }
}

