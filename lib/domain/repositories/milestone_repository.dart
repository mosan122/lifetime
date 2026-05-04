import 'dart:io';

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
    int categoryId = 1,
    List<String> participants = const [],
    bool isPublic = false,
    String? driveFileId,
    String? imageBase64,
    List<String> localMediaPaths = const [],
    List<MediaType> localMediaTypes = const [],
  });

  Future<Either<Failure, List<Milestone>>> getMilestones();

  /// Pulls all milestones from Supabase and upserts them into Isar.
  /// Intended for "new device" bootstrap on premium accounts.
  Future<Either<Failure, void>> syncFromCloud();

  Future<Either<Failure, Milestone>> getMilestoneById(String id);

  Future<Either<Failure, void>> deleteMilestone(
    String id, {
    String? accessToken,
  });

  Future<Either<Failure, Milestone>> updateMilestone({
    required String id,
    required String title,
    required String description,
    int? categoryId,
    DateTime? eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String> participantIds = const [],
    List<MediaItem> mediaToKeep = const [],
    List<File> newMediaFiles = const [],
    List<MediaType> newMediaTypes = const [],
  });
}
