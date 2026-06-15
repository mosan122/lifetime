part of 'people_cubit.dart';

sealed class PeopleState extends Equatable {
  const PeopleState();
}

class PeopleLoading extends PeopleState {
  const PeopleLoading();
  @override
  List<Object?> get props => const [];
}

class PeopleLoaded extends PeopleState {
  const PeopleLoaded(
    this.people,
    this.groups, {
    this.refreshEpoch = 0,
    this.milestoneCountsByPersonId = const {},
  });

  final List<PersonCollection> people;
  final List<GroupCollection> groups;

  /// Hitos en los que participa cada persona (participante o protagonista).
  final Map<String, int> milestoneCountsByPersonId;

  /// Se incrementa en cada [PeopleCubit.reload] (p. ej. tras guardar cara) para
  /// forzar que [BlocBuilder] vuelva a pintar aunque la lista sea similar.
  final int refreshEpoch;

  @override
  List<Object?> get props => [people, groups, refreshEpoch, milestoneCountsByPersonId];
}
