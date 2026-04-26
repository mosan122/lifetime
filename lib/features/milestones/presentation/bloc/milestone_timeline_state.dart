part of 'milestone_timeline_cubit.dart';

abstract class MilestoneTimelineState extends Equatable {
  const MilestoneTimelineState();
}

class MilestoneTimelineInitial extends MilestoneTimelineState {
  const MilestoneTimelineInitial();
  @override
  List<Object?> get props => const [];
}

class MilestoneTimelineLoading extends MilestoneTimelineState {
  const MilestoneTimelineLoading();
  @override
  List<Object?> get props => const [];
}

class MilestoneTimelineLoaded extends MilestoneTimelineState {
  final List<Milestone> milestones;
  const MilestoneTimelineLoaded(this.milestones);
  @override
  List<Object?> get props => [milestones];
}

class MilestoneTimelineError extends MilestoneTimelineState {
  final String message;
  final String? code;
  const MilestoneTimelineError(this.message, {this.code});
  @override
  List<Object?> get props => [message, code];
}
