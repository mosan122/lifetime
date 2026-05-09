import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class CreateMilestoneUseCase implements UseCase<Milestone, CreateMilestoneParams> {
  final MilestoneRepository repository;

  const CreateMilestoneUseCase(this.repository);

  @override
  Future<Either<Failure, Milestone>> call(CreateMilestoneParams params) {
    return repository.createMilestone(
      title: params.title,
      userNote: params.userNote,
      eventDate: params.eventDate,
      savedLocationId: params.savedLocationId,
      locationName: params.locationName,
      locationCity: params.locationCity,
      locationCountry: params.locationCountry,
      latitude: params.latitude,
      longitude: params.longitude,
      categoryId: params.categoryId,
      participants: params.participants,
      protagonistIds: params.protagonistIds,
      isPublic: params.isPublic,
      driveFileId: params.driveFileId,
      imageBase64: params.imageBase64,
      localMediaPaths: params.localMediaPaths,
      localMediaTypes: params.localMediaTypes,
    );
  }
}

class CreateMilestoneParams extends Equatable {
  final String? title;
  final String userNote;
  final DateTime eventDate;
  final int? savedLocationId;
  final String? locationName;
  final String? locationCity;
  final String? locationCountry;
  final double? latitude;
  final double? longitude;
  final String categoryId;
  final List<String> participants;
  final List<String> protagonistIds;
  final bool isPublic;
  final String? driveFileId;
  final String? imageBase64;
  final List<String> localMediaPaths;
  final List<MediaType> localMediaTypes;

  const CreateMilestoneParams({
    this.title,
    required this.userNote,
    required this.eventDate,
    this.savedLocationId,
    this.locationName,
    this.locationCity,
    this.locationCountry,
    this.latitude,
    this.longitude,
    this.categoryId = 'otros',
    this.participants = const [],
    this.protagonistIds = const [],
    this.isPublic = false,
    this.driveFileId,
    this.imageBase64,
    this.localMediaPaths = const [],
    this.localMediaTypes = const [],
  });

  @override
  List<Object?> get props => [
        title,
        userNote,
        eventDate,
        savedLocationId,
        locationName,
        locationCity,
        locationCountry,
        latitude,
        longitude,
        categoryId,
        participants,
        protagonistIds,
        isPublic,
        driveFileId,
        imageBase64,
        localMediaPaths,
        localMediaTypes,
      ];
}
