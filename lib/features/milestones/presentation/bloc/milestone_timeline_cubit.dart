import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/get_milestones_usecase.dart';

part 'milestone_timeline_state.dart';

class MilestoneTimelineCubit extends Cubit<MilestoneTimelineState> {
  final GetMilestonesUseCase _getMilestones;

  MilestoneTimelineCubit(this._getMilestones)
      : super(const MilestoneTimelineInitial());

  Future<void> loadTimeline() async {
    emit(const MilestoneTimelineLoading());
    final result = await _getMilestones(const NoParams());
    result.fold(
      (failure) => emit(MilestoneTimelineError(failure.message, code: failure.code)),
      (milestones) => emit(MilestoneTimelineLoaded(milestones)),
    );
  }
}
