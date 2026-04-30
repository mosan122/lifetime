import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class UpdateMilestoneUseCase implements UseCase<Milestone, UpdateMilestoneParams> {
  final MilestoneRepository repository;

  const UpdateMilestoneUseCase(this.repository);

  @override
  Future<Either<Failure, Milestone>> call(UpdateMilestoneParams params) {
    return repository.updateMilestone(
      id: params.id,
      title: params.title,
      description: params.description,
      eventDate: params.eventDate,
      locationName: params.locationName,
      latitude: params.latitude,
      longitude: params.longitude,
    );
  }
}

class UpdateMilestoneParams extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime? eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  const UpdateMilestoneParams({
    required this.id,
    required this.title,
    required this.description,
    this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props =>
      [id, title, description, eventDate, locationName, latitude, longitude];
}
