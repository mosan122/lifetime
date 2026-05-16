import 'package:isar/isar.dart';

part 'person_group_link_collection.g.dart';

@Collection()
class PersonGroupLinkCollection {
  Id isarId = Isar.autoIncrement;

  /// Clave estable `personId|groupId` (UUID y ids builtin no contienen `|`).
  @Index(unique: true)
  late String linkKey;

  @Index()
  late String personId;

  @Index()
  late String groupId;
}
