import 'package:equatable/equatable.dart';

import '../../data/models/local/person_collection.dart';
import '../../data/models/local/relationship_collection.dart';

/// Familiar directo en el grafo radial (persona + fila de relación deduplicada).
class RelationshipTreeMember extends Equatable {
  const RelationshipTreeMember({
    required this.person,
    required this.relationship,
    required this.kinshipLabel,
    required this.isPastPartner,
  });

  final PersonCollection person;
  final RelationshipCollection relationship;
  final String kinshipLabel;
  final bool isPastPartner;

  @override
  List<Object?> get props => [
        person.id,
        relationship.id,
        kinshipLabel,
        isPastPartner,
      ];
}
