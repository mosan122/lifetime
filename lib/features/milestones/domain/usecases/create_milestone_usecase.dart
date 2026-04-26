import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class CreateMilestoneUseCase implements UseCase<Milestone, CreateMilestoneParams> {
  final MilestoneRepository repository;

  const CreateMilestoneUseCase(this.repository);

  @override
  Future<Either<Failure, Milestone>> call(CreateMilestoneParams params) {
    return repository.createMilestone(
      userNote: params.userNote,
      eventDate: params.eventDate,
      locationName: params.locationName,
      latitude: params.latitude,
      longitude: params.longitude,
      category: params.category,
      participants: params.participants,
      isPublic: params.isPublic,
    );
  }
}

class CreateMilestoneParams extends Equatable {
  final String userNote;
  final DateTime eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String category;
  final List<String> participants;
  final bool isPublic;

  const CreateMilestoneParams({
    required this.userNote,
    required this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.category = 'general',
    this.participants = const [],
    this.isPublic = false,
  });

  @override
  List<Object?> get props => [
        userNote,
        eventDate,
        locationName,
        latitude,
        longitude,
        category,
        participants,
        isPublic,
      ];
}
