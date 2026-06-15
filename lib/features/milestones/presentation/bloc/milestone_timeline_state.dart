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
  const MilestoneTimelineLoaded(
    this.allMilestones, {
    this.filters = TimelineFilters.empty,
  });

  final List<Milestone> allMilestones;
  final TimelineFilters filters;

  List<Milestone> get milestones =>
      applyTimelineFilters(allMilestones, filters);

  MilestoneTimelineLoaded copyWith({
    List<Milestone>? allMilestones,
    TimelineFilters? filters,
  }) {
    return MilestoneTimelineLoaded(
      allMilestones ?? this.allMilestones,
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props => [allMilestones, filters];
}

class MilestoneTimelineError extends MilestoneTimelineState {
  final String message;
  final String? code;
  const MilestoneTimelineError(this.message, {this.code});
  @override
  List<Object?> get props => [message, code];
}
