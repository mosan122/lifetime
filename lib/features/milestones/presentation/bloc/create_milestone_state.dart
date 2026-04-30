part of 'create_milestone_cubit.dart';

abstract class CreateMilestoneState extends Equatable {
  const CreateMilestoneState();
}

class CreateMilestoneInitial extends CreateMilestoneState {
  const CreateMilestoneInitial();
  @override
  List<Object?> get props => const [];
}

class CreateMilestoneSubmitting extends CreateMilestoneState {
  final String step;
  const CreateMilestoneSubmitting([this.step = 'Redactando historia...']);
  @override
  List<Object?> get props => [step];
}

class CreateMilestoneSuccess extends CreateMilestoneState {
  final Milestone milestone;
  const CreateMilestoneSuccess(this.milestone);
  @override
  List<Object?> get props => [milestone];
}

class CreateMilestoneError extends CreateMilestoneState {
  final String message;
  final String? code;
  const CreateMilestoneError(this.message, {this.code});
  @override
  List<Object?> get props => [message, code];
}
