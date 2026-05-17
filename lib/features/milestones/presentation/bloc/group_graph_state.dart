import 'package:equatable/equatable.dart';

import '../../data/models/local/group_collection.dart';
import '../../data/models/local/milestone_collection.dart';
import '../../data/models/local/person_collection.dart';

enum GroupGraphStatus { initial, loading, loaded, error }

class GroupGraphState extends Equatable {
  const GroupGraphState({
    this.status = GroupGraphStatus.initial,
    this.groupId = '',
    this.group,
    this.members = const [],
    this.linkedMilestones = const [],
    this.errorMessage,
  });

  final GroupGraphStatus status;
  final String groupId;
  final GroupCollection? group;
  final List<PersonCollection> members;
  final List<MilestoneCollection> linkedMilestones;
  final String? errorMessage;

  bool get isLoading =>
      status == GroupGraphStatus.loading ||
      status == GroupGraphStatus.initial;

  GroupGraphState copyWith({
    GroupGraphStatus? status,
    String? groupId,
    GroupCollection? group,
    List<PersonCollection>? members,
    List<MilestoneCollection>? linkedMilestones,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupGraphState(
      status: status ?? this.status,
      groupId: groupId ?? this.groupId,
      group: group ?? this.group,
      members: members ?? this.members,
      linkedMilestones: linkedMilestones ?? this.linkedMilestones,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        groupId,
        group?.id,
        group?.name,
        members,
        linkedMilestones,
        errorMessage,
      ];
}
