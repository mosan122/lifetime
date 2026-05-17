import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/datasources/person_group_local_datasource.dart';
import '../../data/models/local/group_collection.dart';
import 'group_graph_state.dart';

class GroupGraphCubit extends Cubit<GroupGraphState> {
  GroupGraphCubit(
    this._groupDs,
    this._personDs,
    this._milestoneDs,
  ) : super(const GroupGraphState());

  final PersonGroupLocalDataSource _groupDs;
  final IsarPersonDataSource _personDs;
  final IsarMilestoneDataSource _milestoneDs;

  Future<void> loadGroup(String groupId) async {
    final gid = groupId.trim();
    if (gid.isEmpty) return;

    emit(
      state.copyWith(
        status: GroupGraphStatus.loading,
        groupId: gid,
        clearError: true,
      ),
    );

    try {
      final groups = await _groupDs.fetchAllGroupsOrdered();
      GroupCollection? group;
      for (final g in groups) {
        if (g.id == gid) {
          group = g;
          break;
        }
      }
      if (group == null) {
        emit(
          state.copyWith(
            status: GroupGraphStatus.error,
            errorMessage: 'No se encontró el grupo.',
          ),
        );
        return;
      }

      final links = await _groupDs.fetchAllLinks();
      final personIds = <String>{
        for (final l in links)
          if (l.groupId == gid) l.personId,
      };

      final members = await _personDs.fetchByIds(personIds.toList());
      members.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      final memberIds = members.map((p) => p.id).toSet();
      final linkedMilestones = (await _milestoneDs.fetchAll())
          .where(
            (m) => m.participants.any(memberIds.contains),
          )
          .toList();

      emit(
        GroupGraphState(
          status: GroupGraphStatus.loaded,
          groupId: gid,
          group: group,
          members: members,
          linkedMilestones: linkedMilestones,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupGraphStatus.error,
          errorMessage: 'No se pudo cargar el grupo: $e',
        ),
      );
    }
  }
}
