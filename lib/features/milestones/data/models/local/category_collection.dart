import 'package:isar/isar.dart';

part 'category_collection.g.dart';

@Collection()
class CategoryCollection {
  /// Auto-increment internal Isar id.
  Id isarId = Isar.autoIncrement;

  /// Stable string id used by milestones (e.g. "viajes", "salud").
  @Index(unique: true, caseSensitive: false)
  late String id;

  /// Display name shown in UI (free text).
  late String name;

  /// Icon key from a closed palette (tree-shake friendly).
  /// Example: "flight", "favorite", "category".
  late String iconName;

  /// ARGB color value (e.g. `0xFF000000`).
  late int colorValue;
}

