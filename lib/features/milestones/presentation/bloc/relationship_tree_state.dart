import 'package:equatable/equatable.dart';

import '../../data/models/local/person_collection.dart';
import '../../domain/models/relationship_tree_member.dart';

enum RelationshipTreeStatus { initial, loading, loaded, error }

class RelationshipTreeState extends Equatable {
  const RelationshipTreeState({
    this.status = RelationshipTreeStatus.initial,
    this.centerPersonId = '',
    this.centerPerson,
    this.parents = const [],
    this.partners = const [],
    this.siblings = const [],
    this.children = const [],
    this.errorMessage,
    this.focusGeneration = 0,
  });

  final RelationshipTreeStatus status;
  final String centerPersonId;
  final PersonCollection? centerPerson;
  final List<RelationshipTreeMember> parents;
  final List<RelationshipTreeMember> partners;
  final List<RelationshipTreeMember> siblings;
  final List<RelationshipTreeMember> children;
  final String? errorMessage;

  /// Se incrementa al cambiar el centro para animaciones en la vista.
  final int focusGeneration;

  bool get isLoading =>
      status == RelationshipTreeStatus.loading ||
      status == RelationshipTreeStatus.initial;

  RelationshipTreeState copyWith({
    RelationshipTreeStatus? status,
    String? centerPersonId,
    PersonCollection? centerPerson,
    List<RelationshipTreeMember>? parents,
    List<RelationshipTreeMember>? partners,
    List<RelationshipTreeMember>? siblings,
    List<RelationshipTreeMember>? children,
    String? errorMessage,
    int? focusGeneration,
    bool clearError = false,
  }) {
    return RelationshipTreeState(
      status: status ?? this.status,
      centerPersonId: centerPersonId ?? this.centerPersonId,
      centerPerson: centerPerson ?? this.centerPerson,
      parents: parents ?? this.parents,
      partners: partners ?? this.partners,
      siblings: siblings ?? this.siblings,
      children: children ?? this.children,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      focusGeneration: focusGeneration ?? this.focusGeneration,
    );
  }

  @override
  List<Object?> get props => [
        status,
        centerPersonId,
        centerPerson?.id,
        centerPerson?.name,
        parents,
        partners,
        siblings,
        children,
        errorMessage,
        focusGeneration,
      ];
}
