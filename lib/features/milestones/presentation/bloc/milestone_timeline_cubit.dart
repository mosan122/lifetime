import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/get_milestones_usecase.dart';

part 'milestone_timeline_state.dart';

class MilestoneTimelineCubit extends Cubit<MilestoneTimelineState> {
  final GetMilestonesUseCase _getMilestones;

  MilestoneTimelineCubit(this._getMilestones)
      : super(const MilestoneTimelineInitial());

  Future<void> loadTimeline() async {
    emit(const MilestoneTimelineLoading());
    await _fetchAndEmitMilestones();
  }

  /// Vuelve a leer hitos sin pantalla de carga (p. ej. tras importar desde Ajustes).
  Future<void> refreshTimeline() async {
    if (state is! MilestoneTimelineLoaded) {
      await loadTimeline();
      return;
    }
    await _fetchAndEmitMilestones();
  }

  Future<void> _fetchAndEmitMilestones() async {
    final result = await _getMilestones(const NoParams());
    result.fold(
      (failure) => emit(MilestoneTimelineError(failure.message, code: failure.code)),
      (milestones) {
        sl<CloudSyncService>().syncIfNeeded(milestones);
        emit(MilestoneTimelineLoaded(milestones));
      },
    );
  }
}
