import 'package:isar/isar.dart';

part 'group_collection.g.dart';

@Collection()
class GroupCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String name;

  /// `true` para filas de [kDefaultContactGroupSeeds] (no borrar por nombre).
  bool builtIn = false;
}
