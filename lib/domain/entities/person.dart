import 'package:equatable/equatable.dart';

/// Represents a person mentioned in biographer text (e.g. "@Ana").
class Person extends Equatable {
  final String id;
  /// Nickname / display name (required).
  final String name;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  /// Free-form group label, e.g. "Familia".
  final String group;
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
    this.group = '',
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
        group,
        notes,
        linkedUserEmail,
        linkedUserId,
        faceImagePath,
        driveFaceFileId,
      ];
}

