import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/update_milestone_usecase.dart';

part 'edit_milestone_state.dart';

class EditMilestoneCubit extends Cubit<EditMilestoneState> {
  final UpdateMilestoneUseCase _updateMilestone;

  EditMilestoneCubit(this._updateMilestone) : super(const EditMilestoneIdle());

  Future<void> submit({
    required String id,
    required String title,
    required String description,
    DateTime? eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    emit(const EditMilestoneSubmitting());
    final result = await _updateMilestone(
      UpdateMilestoneParams(
        id: id,
        title: title,
        description: description,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
      ),
    );
    result.fold(
      (failure) => emit(EditMilestoneError(failure.message)),
      (milestone) => emit(EditMilestoneSuccess(milestone)),
    );
  }
}
