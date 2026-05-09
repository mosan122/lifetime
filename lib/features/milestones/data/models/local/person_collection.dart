import 'package:isar/isar.dart';

import '../../../../../domain/entities/person.dart';

part 'person_collection.g.dart';

// 
@Collection()
class PersonCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  /// Nickname / display name (required).
  late String name;
  String? firstName;
  String? lastName;
  DateTime? birthDate;
  /// Free-form group label, e.g. "Familia".
  String group = '';
  String notes = '';
  String? linkedUserEmail;
  String? linkedUserId;
  String? faceImagePath;
  String? driveFaceFileId;

  static PersonCollection fromEntity(Person person) {
    return PersonCollection()
      ..id = person.id
      ..name = person.name
      ..firstName = person.firstName
      ..lastName = person.lastName
      ..birthDate = person.birthDate
      ..group = person.group
      ..notes = person.notes
      ..linkedUserEmail = person.linkedUserEmail
      ..linkedUserId = person.linkedUserId
      ..faceImagePath = person.faceImagePath
      ..driveFaceFileId = person.driveFaceFileId;
  }

  Person toDomain() {
    return Person(
      id: id,
      name: name,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      group: group,
      notes: notes,
      linkedUserEmail: linkedUserEmail,
      linkedUserId: linkedUserId,
      faceImagePath: faceImagePath,
      driveFaceFileId: driveFaceFileId,
    );
  }
}

