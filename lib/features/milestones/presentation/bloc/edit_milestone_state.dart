part of 'edit_milestone_cubit.dart';

abstract class EditMilestoneState extends Equatable {
  const EditMilestoneState();
}

class EditMilestoneIdle extends EditMilestoneState {
  const EditMilestoneIdle();
  @override
  List<Object?> get props => const [];
}

class EditMilestoneSubmitting extends EditMilestoneState {
  const EditMilestoneSubmitting();
  @override
  List<Object?> get props => const [];
}

class EditMilestoneSuccess extends EditMilestoneState {
  final Milestone milestone;
  const EditMilestoneSuccess(this.milestone);
  @override
  List<Object?> get props => [milestone];
}

class EditMilestoneError extends EditMilestoneState {
  final String message;
  const EditMilestoneError(this.message);
  @override
  List<Object?> get props => [message];
}
