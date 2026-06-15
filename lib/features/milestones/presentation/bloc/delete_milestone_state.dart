part of 'delete_milestone_cubit.dart';

abstract class DeleteMilestoneState extends Equatable {
  const DeleteMilestoneState();
}

class DeleteMilestoneIdle extends DeleteMilestoneState {
  const DeleteMilestoneIdle();
  @override
  List<Object?> get props => const [];
}

class DeleteMilestoneDeleting extends DeleteMilestoneState {
  const DeleteMilestoneDeleting();
  @override
  List<Object?> get props => const [];
}

class DeleteMilestoneSuccess extends DeleteMilestoneState {
  const DeleteMilestoneSuccess();
  @override
  List<Object?> get props => const [];
}

class DeleteMilestoneError extends DeleteMilestoneState {
  final String message;
  const DeleteMilestoneError(this.message);
  @override
  List<Object?> get props => [message];
}
