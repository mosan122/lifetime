import '../../features/milestones/data/models/local/relationship_collection.dart';
import 'relationship_type_codes.dart';

/// Agrupa un vínculo directo respecto a la persona en el centro del árbol.
enum RelationshipTreeQuadrant {
  parents,
  partners,
  siblings,
  children,
  skip,
}

abstract final class RelationshipTreeKinship {
  static RelationshipTreeQuadrant quadrantForRow(
    RelationshipCollection row,
    String viewerId,
  ) {
    final type = row.relationshipType;
    final viewerIsSubject = row.personId == viewerId;

    switch (type) {
      case RelationshipTypeCodes.esPadreDe:
      case RelationshipTypeCodes.esMadreDe:
        return viewerIsSubject
            ? RelationshipTreeQuadrant.children
            : RelationshipTreeQuadrant.parents;
      case RelationshipTypeCodes.esHijoDe:
      case RelationshipTypeCodes.esHijaDe:
        return viewerIsSubject
            ? RelationshipTreeQuadrant.parents
            : RelationshipTreeQuadrant.children;
      case RelationshipTypeCodes.esAbueloDe:
      case RelationshipTypeCodes.esAbuelaDe:
        return viewerIsSubject
            ? RelationshipTreeQuadrant.children
            : RelationshipTreeQuadrant.parents;
      case RelationshipTypeCodes.esNietoDe:
      case RelationshipTypeCodes.esNietaDe:
        return viewerIsSubject
            ? RelationshipTreeQuadrant.parents
            : RelationshipTreeQuadrant.children;
      case RelationshipTypeCodes.esHermanoDe:
        return RelationshipTreeQuadrant.siblings;
      case RelationshipTypeCodes.esConyugeDe:
      case RelationshipTypeCodes.esParejaDe:
        return RelationshipTreeQuadrant.partners;
      default:
        return RelationshipTreeQuadrant.skip;
    }
  }

  /// Etiqueta corta del parentesco del otro respecto al centro (p. ej. «Padre»).
  static String shortLabelForRow(
    RelationshipCollection row,
    String viewerId,
  ) {
    final viewerIsSubject = row.personId == viewerId;
    final type = row.relationshipType;

    if (viewerIsSubject) {
      return _shortWhenViewerIsSubject(type);
    }
    return _shortWhenViewerIsRelated(type);
  }

  static String _shortWhenViewerIsSubject(String type) {
    switch (type) {
      case RelationshipTypeCodes.esPadreDe:
        return 'Hijo/a';
      case RelationshipTypeCodes.esMadreDe:
        return 'Hijo/a';
      case RelationshipTypeCodes.esHijoDe:
        return 'Padre';
      case RelationshipTypeCodes.esHijaDe:
        return 'Madre';
      case RelationshipTypeCodes.esHermanoDe:
        return 'Hermano/a';
      case RelationshipTypeCodes.esConyugeDe:
        return 'Cónyuge';
      case RelationshipTypeCodes.esParejaDe:
        return 'Pareja';
      case RelationshipTypeCodes.esAbueloDe:
      case RelationshipTypeCodes.esAbuelaDe:
        return 'Nieto/a';
      case RelationshipTypeCodes.esNietoDe:
      case RelationshipTypeCodes.esNietaDe:
        return 'Abuelo/a';
      default:
        return 'Vínculo';
    }
  }

  static String _shortWhenViewerIsRelated(String type) {
    switch (type) {
      case RelationshipTypeCodes.esPadreDe:
        return 'Padre';
      case RelationshipTypeCodes.esMadreDe:
        return 'Madre';
      case RelationshipTypeCodes.esHijoDe:
      case RelationshipTypeCodes.esHijaDe:
        return 'Hijo/a';
      case RelationshipTypeCodes.esHermanoDe:
        return 'Hermano/a';
      case RelationshipTypeCodes.esConyugeDe:
        return 'Cónyuge';
      case RelationshipTypeCodes.esParejaDe:
        return 'Pareja';
      case RelationshipTypeCodes.esAbueloDe:
      case RelationshipTypeCodes.esAbuelaDe:
        return 'Abuelo/a';
      case RelationshipTypeCodes.esNietoDe:
      case RelationshipTypeCodes.esNietaDe:
        return 'Nieto/a';
      default:
        return 'Vínculo';
    }
  }

  static bool isPartnerType(String type) {
    return type == RelationshipTypeCodes.esConyugeDe ||
        type == RelationshipTypeCodes.esParejaDe;
  }
}
