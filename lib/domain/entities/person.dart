import 'package:equatable/equatable.dart';

/// Represents a person mentioned in biographer text (e.g. "@Ana").
class Person extends Equatable {
  final String id;
  final String name;
  final String? faceImagePath;
  final String? driveFaceFileId;

  const Person({
    required this.id,
    required this.name,
    this.faceImagePath,
    this.driveFaceFileId,
  });

  @override
  List<Object?> get props => [id, name, faceImagePath, driveFaceFileId];
}

