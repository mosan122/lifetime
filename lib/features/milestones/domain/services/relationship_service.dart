import 'package:uuid/uuid.dart';

import '../../../../domain/relationships/relationship_reciprocity.dart';
import '../../../../domain/relationships/relationship_type_codes.dart';
import '../../data/datasources/isar_relationship_datasource.dart';
import '../../data/models/local/relationship_collection.dart';

/// Persistencia local de vínculos entre personas y reciprocidad sugerida.
class RelationshipService {
  RelationshipService(this._ds);

  final IsarRelationshipDataSource _ds;
  static const _uuid = Uuid();

  RelationshipCollection buildRow({
    required String personId,
    required String relatedPersonId,
    required String relationshipType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    String? id,
  }) {
    final end = endDate;
    final current = isCurrent ?? (end == null);
    return RelationshipCollection()
      ..id = id ?? _uuid.v4()
      ..personId = personId.trim()
      ..relatedPersonId = relatedPersonId.trim()
      ..relationshipType = relationshipType
      ..startDate = startDate
      ..endDate = endDate
      ..isCurrent = current;
  }

  Future<void> saveRow(RelationshipCollection row) => _ds.put(row);

  /// Crea la fila espejo según [plan] (tipos y fechas alineados con la original).
  Future<void> saveMirrorIfNeeded({
    required String subjectId,
    required String objectId,
    required String forwardType,
    required RelationshipMirrorPlan plan,
    String? chosenMirrorType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
  }) async {
    switch (plan.mode) {
      case RelationshipMirrorMode.none:
        return;
      case RelationshipMirrorMode.symmetricAuto:
        final mt = plan.mirrorType ?? forwardType;
        final mirror = buildRow(
          personId: objectId,
          relatedPersonId: subjectId,
          relationshipType: mt,
          startDate: startDate,
          endDate: endDate,
          isCurrent: isCurrent,
        );
        await _ds.put(mirror);
        return;
      case RelationshipMirrorMode.singleMirror:
        final mt = plan.mirrorType;
        if (mt == null) return;
        final mirror = buildRow(
          personId: objectId,
          relatedPersonId: subjectId,
          relationshipType: mt,
          startDate: startDate,
          endDate: endDate,
          isCurrent: isCurrent,
        );
        await _ds.put(mirror);
        return;
      case RelationshipMirrorMode.chooseMirrorType:
        final mt = chosenMirrorType;
        if (mt == null) return;
        final mirror = buildRow(
          personId: objectId,
          relatedPersonId: subjectId,
          relationshipType: mt,
          startDate: startDate,
          endDate: endDate,
          isCurrent: isCurrent,
        );
        await _ds.put(mirror);
        return;
    }
  }

  static RelationshipMirrorPlan planFor(String forwardType) =>
      RelationshipReciprocity.planMirrorForType(forwardType);

  /// Tipos que mostramos como “destacados” en la ficha (progenitores y pareja).
  static bool isPrimaryHighlight(String type) {
    return type == RelationshipTypeCodes.esPadreDe ||
        type == RelationshipTypeCodes.esMadreDe ||
        type == RelationshipTypeCodes.esConyugeDe ||
        type == RelationshipTypeCodes.esParejaDe;
  }

  static bool isPast(RelationshipCollection r) =>
      r.endDate != null || !r.isCurrent;

  /// Fila inversa del mismo par (dirección opuesta y tipo espejo coherente), si existe en [all].
  RelationshipCollection? findInverseRow(
    RelationshipCollection forward,
    List<RelationshipCollection> all,
  ) {
    final plan = RelationshipReciprocity.planMirrorForType(forward.relationshipType);
    if (plan.mode == RelationshipMirrorMode.none) return null;
    for (final c in all) {
      if (c.id == forward.id) continue;
      if (c.personId != forward.relatedPersonId ||
          c.relatedPersonId != forward.personId) {
        continue;
      }
      if (_mirrorTypeMatches(plan, forward.relationshipType, c.relationshipType)) {
        return c;
      }
    }
    return null;
  }

  static bool _mirrorTypeMatches(
    RelationshipMirrorPlan plan,
    String forwardType,
    String mirrorType,
  ) {
    switch (plan.mode) {
      case RelationshipMirrorMode.none:
        return false;
      case RelationshipMirrorMode.symmetricAuto:
        final expected = plan.mirrorType ?? forwardType;
        return mirrorType == expected;
      case RelationshipMirrorMode.singleMirror:
        return mirrorType == plan.mirrorType;
      case RelationshipMirrorMode.chooseMirrorType:
        return plan.mirrorTypeChoices.contains(mirrorType);
    }
  }
}
