import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../features/sync/data/services/sync_service.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/get_milestones_usecase.dart';

part 'milestone_timeline_state.dart';

class MilestoneTimelineCubit extends Cubit<MilestoneTimelineState> {
  final GetMilestonesUseCase _getMilestones;

  MilestoneTimelineCubit(this._getMilestones)
      : super(const MilestoneTimelineInitial());

  Future<void> loadTimeline() async {
    emit(const MilestoneTimelineLoading());
    _scheduleBackgroundSync();
    await _fetchAndEmitMilestones();
  }

  void _scheduleBackgroundSync() {
    if (!sl.isRegistered<PremiumService>() ||
        !sl.isRegistered<SyncService>()) {
      return;
    }
    if (sl<PremiumService>().isPremium) {
      unawaited(sl<SyncService>().syncIfNeededForTimelineOpen());
    }
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
      (milestones) => emit(MilestoneTimelineLoaded(milestones)),
    );
  }
}
