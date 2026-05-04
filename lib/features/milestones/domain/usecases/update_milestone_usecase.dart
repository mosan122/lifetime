import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/media_item.dart';
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
      categoryId: params.categoryId,
      eventDate: params.eventDate,
      locationName: params.locationName,
      latitude: params.latitude,
      longitude: params.longitude,
      participantIds: params.participantIds,
      mediaToKeep: params.mediaToKeep,
      newMediaFiles: params.newMediaFiles,
      newMediaTypes: params.newMediaTypes,
    );
  }
}

class UpdateMilestoneParams extends Equatable {
  final String id;
  final String title;
  final String description;
  final int? categoryId;
  final DateTime? eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final List<String> participantIds;
  final List<MediaItem> mediaToKeep;
  final List<File> newMediaFiles;
  final List<MediaType> newMediaTypes;

  const UpdateMilestoneParams({
    required this.id,
    required this.title,
    required this.description,
    this.categoryId,
    this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.participantIds = const [],
    this.mediaToKeep = const [],
    this.newMediaFiles = const [],
    this.newMediaTypes = const [],
  });

  @override
  List<Object?> get props => [
        id, title, description, categoryId, eventDate,
        locationName, latitude, longitude,
        participantIds, mediaToKeep, newMediaFiles, newMediaTypes,
      ];
}
