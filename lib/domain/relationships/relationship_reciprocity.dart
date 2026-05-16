import 'relationship_type_codes.dart';

/// Resultado de analizar si hace falta fila espejo y con qué tipo.
enum RelationshipMirrorMode {
  /// No se crea segunda fila (o ya es implícito).
  none,

  /// Se crea la inversa automáticamente (hermano, pareja, etc.).
  symmetricAuto,

  /// Proponer un único tipo espejo (p. ej. padre → hijo).
  singleMirror,

  /// El usuario debe elegir entre varios tipos espejo (hijo → padre o madre).
  chooseMirrorType,
}

class RelationshipMirrorPlan {
  const RelationshipMirrorPlan({
    required this.mode,
    this.mirrorType,
    this.mirrorTypeChoices = const [],
  });

  final RelationshipMirrorMode mode;
  final String? mirrorType;
  final List<String> mirrorTypeChoices;
}

/// Lógica de reciprocidad entre personas (tipos declarados en [RelationshipTypeCodes]).
abstract final class RelationshipReciprocity {
  static RelationshipMirrorPlan planMirrorForType(String forwardType) {
    switch (forwardType) {
      case RelationshipTypeCodes.esPadreDe:
      case RelationshipTypeCodes.esMadreDe:
        return const RelationshipMirrorPlan(
          mode: RelationshipMirrorMode.singleMirror,
          mirrorType: RelationshipTypeCodes.esHijoDe,
        );
      case RelationshipTypeCodes.esHijoDe:
      case RelationshipTypeCodes.esHijaDe:
        return const RelationshipMirrorPlan(
          mode: RelationshipMirrorMode.chooseMirrorType,
          mirrorTypeChoices: [
            RelationshipTypeCodes.esPadreDe,
            RelationshipTypeCodes.esMadreDe,
          ],
        );
      case RelationshipTypeCodes.esAbueloDe:
      case RelationshipTypeCodes.esAbuelaDe:
        return const RelationshipMirrorPlan(
          mode: RelationshipMirrorMode.singleMirror,
          mirrorType: RelationshipTypeCodes.esNietoDe,
        );
      case RelationshipTypeCodes.esNietoDe:
      case RelationshipTypeCodes.esNietaDe:
        return const RelationshipMirrorPlan(
          mode: RelationshipMirrorMode.chooseMirrorType,
          mirrorTypeChoices: [
            RelationshipTypeCodes.esAbueloDe,
            RelationshipTypeCodes.esAbuelaDe,
          ],
        );
      case RelationshipTypeCodes.esHermanoDe:
      case RelationshipTypeCodes.esConyugeDe:
      case RelationshipTypeCodes.esParejaDe:
        return RelationshipMirrorPlan(
          mode: RelationshipMirrorMode.symmetricAuto,
          mirrorType: forwardType,
        );
      case RelationshipTypeCodes.otro:
        return const RelationshipMirrorPlan(mode: RelationshipMirrorMode.none);
      default:
        return const RelationshipMirrorPlan(mode: RelationshipMirrorMode.none);
    }
  }

  /// Fila espejo: [objectId] --mirrorType--> [subjectId]
  static Map<String, Object?> mirrorRowFields({
    required String subjectId,
    required String objectId,
    required String mirrorType,
    required DateTime? startDate,
    required DateTime? endDate,
    required bool isCurrent,
  }) {
    return <String, Object?>{
      'personId': objectId,
      'relatedPersonId': subjectId,
      'relationshipType': mirrorType,
      'startDate': startDate,
      'endDate': endDate,
      'isCurrent': isCurrent,
    };
  }
}
