import 'package:isar/isar.dart';

part 'category_collection.g.dart';

@Collection()
class CategoryCollection {
  /// Auto-increment internal Isar id.
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String name;

  /// Stored as a string so we can map it to Material icons in UI.
  /// Example: "cake", "favorite", "star".
  late String iconName;

  /// ARGB color value (e.g. `0xFF000000`).
  late int colorValue;

  /// System categories are seeded and cannot be deleted or renamed.
  late bool isSystem;
}

