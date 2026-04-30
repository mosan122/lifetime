import 'package:isar/isar.dart';

import '../../../../../domain/entities/person.dart';

part 'person_collection.g.dart';

// 
@Collection()
class PersonCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String displayName;

  static PersonCollection fromEntity(Person person) {
    return PersonCollection()
      ..id = person.id
      ..displayName = person.displayName;
  }

  Person toDomain() {
    return Person(id: id, displayName: displayName);
  }
}

