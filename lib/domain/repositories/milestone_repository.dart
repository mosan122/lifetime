import 'package:dartz/dartz.dart';
import '../entities/milestone.dart';
import '../../core/failures/failure.dart';

abstract class MilestoneRepository {
  Future<Either<Failure, Milestone>> createMilestone({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  });

  Future<Either<Failure, List<Milestone>>> getMilestones();

  Future<Either<Failure, Milestone>> getMilestoneById(String id);
}
