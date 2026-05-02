import 'package:isar/isar.dart';

import '../../../../../domain/entities/person.dart';

part 'person_collection.g.dart';

// 
@Collection()
class PersonCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String name;
  String? faceImagePath;
  String? driveFaceFileId;

  static PersonCollection fromEntity(Person person) {
    return PersonCollection()
      ..id = person.id
      ..name = person.name
      ..faceImagePath = person.faceImagePath
      ..driveFaceFileId = person.driveFaceFileId;
  }

  Person toDomain() {
    return Person(
      id: id,
      name: name,
      faceImagePath: faceImagePath,
      driveFaceFileId: driveFaceFileId,
    );
  }
}

