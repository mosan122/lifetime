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
      savedLocationId: params.savedLocationId,
      locationName: params.locationName,
      locationCity: params.locationCity,
      locationCountry: params.locationCountry,
      latitude: params.latitude,
      longitude: params.longitude,
      participantIds: params.participantIds,
      protagonistIds: params.protagonistIds,
      mediaToKeep: params.mediaToKeep,
      newMediaFiles: params.newMediaFiles,
      newMediaTypes: params.newMediaTypes,
      galleryCoverIndex: params.galleryCoverIndex,
    );
  }
}

class UpdateMilestoneParams extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? categoryId;
  final DateTime? eventDate;
  final int? savedLocationId;
  final String? locationName;
  final String? locationCity;
  final String? locationCountry;
  final double? latitude;
  final double? longitude;
  final List<String> participantIds;
  final List<String> protagonistIds;
  final List<MediaItem> mediaToKeep;
  final List<File> newMediaFiles;
  final List<MediaType> newMediaTypes;
  final int? galleryCoverIndex;

  const UpdateMilestoneParams({
    required this.id,
    required this.title,
    required this.description,
    this.categoryId,
    this.eventDate,
    this.savedLocationId,
    this.locationName,
    this.locationCity,
    this.locationCountry,
    this.latitude,
    this.longitude,
    this.participantIds = const [],
    this.protagonistIds = const [],
    this.mediaToKeep = const [],
    this.newMediaFiles = const [],
    this.newMediaTypes = const [],
    this.galleryCoverIndex,
  });

  @override
  List<Object?> get props => [
        id, title, description, categoryId, eventDate,
        savedLocationId,
        locationName, locationCity, locationCountry, latitude, longitude,
        participantIds, protagonistIds, mediaToKeep, newMediaFiles, newMediaTypes,
        galleryCoverIndex,
      ];
}
