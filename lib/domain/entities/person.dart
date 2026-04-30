import 'package:equatable/equatable.dart';

/// Represents a person mentioned in biographer text (e.g. "@Ana").
class Person extends Equatable {
  final String id;
  final String displayName;

  const Person({
    required this.id,
    required this.displayName,
  });

  @override
  List<Object?> get props => [id, displayName];
}

