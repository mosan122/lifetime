import 'package:isar/isar.dart';

import '../../../../../domain/entities/person.dart';

part 'person_collection.g.dart';

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

  /// Campo legado (una sola etiqueta); migrado a enlaces [PersonGroupLinkCollection].
  String group = '';

  String notes = '';
  String? linkedUserEmail;
  String? linkedUserId;
  String? faceImagePath;
  String? driveFaceFileId;

  String? supabaseId;
  bool isSynced = false;
  bool isDeleted = false;

  /// Relleno en memoria tras cargar enlaces de grupos (no persiste en Isar).
  @ignore
  List<String> runtimeGroupIds = [];

  PersonCollection copyScalars() {
    return PersonCollection()
      ..isarId = isarId
      ..id = id
      ..name = name
      ..firstName = firstName
      ..lastName = lastName
      ..birthDate = birthDate
      ..group = group
      ..notes = notes
      ..linkedUserEmail = linkedUserEmail
      ..linkedUserId = linkedUserId
      ..faceImagePath = faceImagePath
      ..driveFaceFileId = driveFaceFileId
      ..supabaseId = supabaseId
      ..isSynced = isSynced;
  }

  static PersonCollection fromEntity(Person person) {
    return PersonCollection()
      ..id = person.id
      ..name = person.name
      ..firstName = person.firstName
      ..lastName = person.lastName
      ..birthDate = person.birthDate
      ..group = ''
      ..notes = person.notes
      ..linkedUserEmail = person.linkedUserEmail
      ..linkedUserId = person.linkedUserId
      ..faceImagePath = person.faceImagePath
      ..driveFaceFileId = person.driveFaceFileId
      ..runtimeGroupIds = List<String>.from(person.groupIds);
  }

  Person toDomain() {
    return Person(
      id: id,
      name: name,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      groupIds: List<String>.from(runtimeGroupIds),
      notes: notes,
      linkedUserEmail: linkedUserEmail,
      linkedUserId: linkedUserId,
      faceImagePath: faceImagePath,
      driveFaceFileId: driveFaceFileId,
    );
  }
}
