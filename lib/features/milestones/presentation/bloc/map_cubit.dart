import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/get_milestones_usecase.dart';

part 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  final GetMilestonesUseCase _getMilestones;

  MapCubit(this._getMilestones) : super(const MapInitial());

  Future<void> loadMap() async {
    emit(const MapLoading());
    final result = await _getMilestones(const NoParams());
    result.fold(
      (failure) => emit(MapError(failure.message, code: failure.code)),
      (milestones) {
        final located = milestones
            .where((m) => m.latitude != null && m.longitude != null)
            .toList();
        emit(MapLoaded(allMilestones: milestones, locatedMilestones: located));
      },
    );
  }
}
