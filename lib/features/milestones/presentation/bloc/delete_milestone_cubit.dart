import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_milestone_usecase.dart';

part 'delete_milestone_state.dart';

class DeleteMilestoneCubit extends Cubit<DeleteMilestoneState> {
  final DeleteMilestoneUseCase _deleteMilestone;

  DeleteMilestoneCubit(this._deleteMilestone) : super(const DeleteMilestoneIdle());

  Future<void> delete(String id, {String? accessToken}) async {
    emit(const DeleteMilestoneDeleting());
    final result = await _deleteMilestone(
      DeleteMilestoneParams(id, accessToken: accessToken),
    );
    result.fold(
      (failure) => emit(DeleteMilestoneError(failure.message)),
      (_) => emit(const DeleteMilestoneSuccess()),
    );
  }
}
