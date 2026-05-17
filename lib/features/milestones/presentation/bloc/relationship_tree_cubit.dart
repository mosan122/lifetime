import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/relationships/relationship_reciprocity.dart';
import '../../../../domain/relationships/relationship_tree_kinship.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/datasources/isar_relationship_datasource.dart';
import '../../data/models/local/relationship_collection.dart';
import '../../domain/models/relationship_tree_member.dart';
import '../../domain/services/relationship_service.dart';
import 'relationship_tree_state.dart';

class RelationshipTreeCubit extends Cubit<RelationshipTreeState> {
  RelationshipTreeCubit(
    this._relationshipDs,
    this._personDs,
    this._relationshipService,
  ) : super(const RelationshipTreeState());

  final IsarRelationshipDataSource _relationshipDs;
  final IsarPersonDataSource _personDs;
  final RelationshipService _relationshipService;

  Future<void> setCenterPerson(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;

    final sameCenter =
        state.status == RelationshipTreeStatus.loaded &&
            state.centerPersonId == pid;
    if (!sameCenter) {
      emit(
        state.copyWith(
          status: RelationshipTreeStatus.loading,
          centerPersonId: pid,
          clearError: true,
        ),
      );
    }

    try {
      final center = await _personDs.fetchById(pid);
      if (center == null) {
        emit(
          state.copyWith(
            status: RelationshipTreeStatus.error,
            errorMessage: 'No se encontró la persona.',
          ),
        );
        return;
      }

      final rows =
          await _relationshipDs.findInvolvingPerson(pid);
      final displayRows = _dedupeReciprocalRowsForViewer(
        rows,
        pid,
      );

      final ids = <String>{pid};
      for (final r in displayRows) {
        ids.add(r.personId);
        ids.add(r.relatedPersonId);
      }
      final people = await _personDs.fetchByIds(ids.toList());
      final byId = {for (final p in people) p.id: p};

      final parents = <RelationshipTreeMember>[];
      final partners = <RelationshipTreeMember>[];
      final siblings = <RelationshipTreeMember>[];
      final children = <RelationshipTreeMember>[];

      for (final row in displayRows) {
        final otherId =
            row.personId == pid ? row.relatedPersonId : row.personId;
        final other = byId[otherId];
        if (other == null) continue;

        final quadrant = RelationshipTreeKinship.quadrantForRow(row, pid);
        final member = RelationshipTreeMember(
          person: other,
          relationship: row,
          kinshipLabel: RelationshipTreeKinship.shortLabelForRow(row, pid),
          isPastPartner: RelationshipTreeKinship.isPartnerType(
                row.relationshipType,
              ) &&
              RelationshipService.isPast(row),
        );

        switch (quadrant) {
          case RelationshipTreeQuadrant.parents:
            parents.add(member);
          case RelationshipTreeQuadrant.partners:
            partners.add(member);
          case RelationshipTreeQuadrant.siblings:
            siblings.add(member);
          case RelationshipTreeQuadrant.children:
            children.add(member);
          case RelationshipTreeQuadrant.skip:
            break;
        }
      }

      void sortMembers(List<RelationshipTreeMember> list) {
        list.sort(
          (a, b) => a.person.name
              .toLowerCase()
              .compareTo(b.person.name.toLowerCase()),
        );
      }

      sortMembers(parents);
      sortMembers(partners);
      sortMembers(siblings);
      sortMembers(children);

      emit(
        RelationshipTreeState(
          status: RelationshipTreeStatus.loaded,
          centerPersonId: pid,
          centerPerson: center,
          parents: parents,
          partners: partners,
          siblings: siblings,
          children: children,
          focusGeneration: sameCenter ? state.focusGeneration : state.focusGeneration + 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RelationshipTreeStatus.error,
          errorMessage: 'No se pudo cargar el árbol: $e',
        ),
      );
    }
  }

  List<RelationshipCollection> _dedupeReciprocalRowsForViewer(
    List<RelationshipCollection> all,
    String viewerId,
  ) {
    final skipIds = <String>{};

    for (final r in all) {
      if (skipIds.contains(r.id)) continue;
      final inv = _relationshipService.findInverseRow(r, all);
      if (inv == null || skipIds.contains(inv.id)) continue;

      final mode = RelationshipReciprocity.planMirrorForType(r.relationshipType)
          .mode;
      if (mode == RelationshipMirrorMode.none) continue;

      if (mode == RelationshipMirrorMode.symmetricAuto) {
        if (r.id.compareTo(inv.id) <= 0) {
          skipIds.add(inv.id);
        } else {
          skipIds.add(r.id);
        }
        continue;
      }

      final rIsViewerSubject = r.personId == viewerId;
      final invIsViewerSubject = inv.personId == viewerId;
      if (rIsViewerSubject && !invIsViewerSubject) {
        skipIds.add(inv.id);
      } else if (invIsViewerSubject && !rIsViewerSubject) {
        skipIds.add(r.id);
      } else if (r.id.compareTo(inv.id) <= 0) {
        skipIds.add(inv.id);
      } else {
        skipIds.add(r.id);
      }
    }

    return all.where((r) => !skipIds.contains(r.id)).toList();
  }
}
