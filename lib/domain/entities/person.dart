import 'package:equatable/equatable.dart';

/// Represents a person mentioned in biographer text (e.g. "@Ana").
class Person extends Equatable {
  final String id;
  /// Nickname / display name (required).
  final String name;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  /// Ids de [GroupCollection] (predeterminados o personalizados).
  final List<String> groupIds;
  final String notes;
  final String? linkedUserEmail;
  final String? linkedUserId;
  final String? faceImagePath;
  final String? driveFaceFileId;

  const Person({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.groupIds = const [],
    this.notes = '',
    this.linkedUserEmail,
    this.linkedUserId,
    this.faceImagePath,
    this.driveFaceFileId,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        firstName,
        lastName,
        birthDate,
        groupIds,
        notes,
        linkedUserEmail,
        linkedUserId,
        faceImagePath,
        driveFaceFileId,
      ];
}
