import 'package:isar/isar.dart';

part 'relationship_collection.g.dart';

@Collection()
class RelationshipCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  /// Persona que “declara” el vínculo (sujeto del rol [relationshipType]).
  @Index()
  late String personId;

  /// La otra persona.
  @Index()
  late String relatedPersonId;

  /// Código semántico (ver [RelationshipTypeCodes]).
  late String relationshipType;

  DateTime? startDate;
  DateTime? endDate;

  /// `true` si el vínculo sigue vigente (puede calcularse con [endDate] == null).
  late bool isCurrent;

  String? supabaseId;
  bool isSynced = false;
  bool isDeleted = false;
}
