import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/create_milestone_usecase.dart';

part 'create_milestone_state.dart';

class CreateMilestoneCubit extends Cubit<CreateMilestoneState> {
  final CreateMilestoneUseCase _createMilestone;

  CreateMilestoneCubit(this._createMilestone)
      : super(const CreateMilestoneInitial());

  Future<void> submit({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  }) async {
    emit(const CreateMilestoneSubmitting());
    final result = await _createMilestone(CreateMilestoneParams(
      userNote: userNote,
      eventDate: eventDate,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      category: category,
      participants: participants,
      isPublic: isPublic,
    ));
    result.fold(
      (failure) =>
          emit(CreateMilestoneError(failure.message, code: failure.code)),
      (milestone) => emit(CreateMilestoneSuccess(milestone)),
    );
  }
}
