part of 'map_cubit.dart';

abstract class MapState extends Equatable {
  const MapState();
}

class MapInitial extends MapState {
  const MapInitial();
  @override
  List<Object?> get props => const [];
}

class MapLoading extends MapState {
  const MapLoading();
  @override
  List<Object?> get props => const [];
}

class MapLoaded extends MapState {
  final List<Milestone> allMilestones;
  final List<Milestone> locatedMilestones;

  const MapLoaded({
    required this.allMilestones,
    required this.locatedMilestones,
  });

  @override
  List<Object?> get props => [allMilestones, locatedMilestones];
}

class MapError extends MapState {
  final String message;
  final String? code;

  const MapError(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}
