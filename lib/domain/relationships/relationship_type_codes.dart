/// Claves persistidas en [RelationshipCollection.relationshipType].
/// Semántica: la persona [personId] cumple este rol respecto a [relatedPersonId].
abstract final class RelationshipTypeCodes {
  static const esPadreDe = 'es_padre_de';
  static const esMadreDe = 'es_madre_de';
  static const esHijoDe = 'es_hijo_de';
  static const esHijaDe = 'es_hija_de';
  static const esHermanoDe = 'es_hermano_de';
  static const esConyugeDe = 'es_conyuge_de';
  static const esParejaDe = 'es_pareja_de';
  static const esAmigoDe = 'es_amigo_de';
  static const esAbueloDe = 'es_abuelo_de';
  static const esAbuelaDe = 'es_abuela_de';
  static const esNietoDe = 'es_nieto_de';
  static const esNietaDe = 'es_nieta_de';
  static const esTioDe = 'es_tio_de';
  static const esTiaDe = 'es_tia_de';
  static const esSobrinoDe = 'es_sobrino_de';
  static const esSobrinaDe = 'es_sobrina_de';
  static const otro = 'otro';

  static const List<String> pickerOrdered = [
    esPadreDe,
    esMadreDe,
    esHijoDe,
    esHijaDe,
    esHermanoDe,
    esConyugeDe,
    esParejaDe,
    esAbueloDe,
    esAbuelaDe,
    esNietoDe,
    esNietaDe,
    esTioDe,
    esTiaDe,
    esSobrinoDe,
    esSobrinaDe,
    otro,
  ];

  static String labelEs(String code) {
    switch (code) {
      case esPadreDe:
        return 'Padre de';
      case esMadreDe:
        return 'Madre de';
      case esHijoDe:
        return 'Hijo de';
      case esHijaDe:
        return 'Hija de';
      case esHermanoDe:
        return 'Hermano/a de';
      case esConyugeDe:
        return 'Cónyuge de';
      case esParejaDe:
        return 'Pareja de';
      case esAmigoDe:
        return 'Conexión con';
      case esAbueloDe:
        return 'Abuelo de';
      case esAbuelaDe:
        return 'Abuela de';
      case esNietoDe:
        return 'Nieto de';
      case esNietaDe:
        return 'Nieta de';
      case esTioDe:
        return 'Tío de';
      case esTiaDe:
        return 'Tía de';
      case esSobrinoDe:
        return 'Sobrino de';
      case esSobrinaDe:
        return 'Sobrina de';
      case otro:
        return 'Otro vínculo con';
      default:
        return code;
    }
  }

  /// [namePersonId] / [nameRelatedPersonId]: nombres para ambos extremos.
  static String labelFromStoredRow({
    required String personId,
    required String relatedPersonId,
    required String relationshipType,
    required String viewerPersonId,
    required String namePersonId,
    required String nameRelatedPersonId,
  }) {
    final otherName =
        viewerPersonId == personId ? nameRelatedPersonId : namePersonId;
    if (viewerPersonId == personId) {
      return '${labelEs(relationshipType)} $otherName';
    }
    return inverseLabelForViewer(relationshipType, otherName);
  }

  static String inverseLabelForViewer(String forwardType, String ownerName) {
    switch (forwardType) {
      case esPadreDe:
        return '$ownerName es tu padre';
      case esMadreDe:
        return '$ownerName es tu madre';
      case esHijoDe:
      case esHijaDe:
        return '$ownerName es hijo/a tuyo/a';
      case esHermanoDe:
        return 'Hermano/a: $ownerName';
      case esConyugeDe:
      case esParejaDe:
        return 'Pareja: $ownerName';
      case esAmigoDe:
        return 'Conexión: $ownerName';
      case esAbueloDe:
      case esAbuelaDe:
        return '$ownerName es tu abuelo/a';
      case esNietoDe:
      case esNietaDe:
        return '$ownerName es nieto/a tuyo/a';
      case esTioDe:
        return '$ownerName es tu tío';
      case esTiaDe:
        return '$ownerName es tu tía';
      case esSobrinoDe:
      case esSobrinaDe:
        return '$ownerName es sobrino/a tuyo/a';
      default:
        return '$ownerName (${labelEs(forwardType)})';
    }
  }
}
