import 'package:dartz/dartz.dart';
import '../entities/media_item.dart';
import '../entities/milestone.dart';
import '../../core/failures/failure.dart';

abstract class MilestoneRepository {
  Future<Either<Failure, Milestone>> createMilestone({
    String? title,
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
    String? driveFileId,
    String? imageBase64,
    List<String> localMediaPaths = const [],
    List<MediaType> localMediaTypes = const [],
  });

  Future<Either<Failure, List<Milestone>>> getMilestones();

  Future<Either<Failure, Milestone>> getMilestoneById(String id);

  Future<Either<Failure, void>> deleteMilestone(
    String id, {
    String? accessToken,
  });

  Future<Either<Failure, Milestone>> updateMilestone({
    required String id,
    required String title,
    required String description,
    DateTime? eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
  });
}
