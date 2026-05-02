// lib/data/repositories/milestone_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/failures/failure.dart';
import '../../core/services/local_media_store.dart';
import '../../core/services/text_metadata_extractor.dart';
import '../../core/services/premium_service.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/drive_repository.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/isar_milestone_datasource.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/datasources/isar_category_datasource.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import '../../features/milestones/data/models/local/media_item_embed.dart';
import '../../features/milestones/data/models/local/person_collection.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final IsarMilestoneDataSource _local;
  final MilestoneRemoteDataSource _remote;
  final PremiumService _premium;
  final String Function() _getUserId;
  final DriveRepository _drive;
  final LocalMediaStore _localMedia;
  final IsarPersonDataSource _people;
  final IsarCategoryDataSource _categories;

  MilestoneRepositoryImpl(
    this._local,
    this._remote,
    this._premium,
    this._getUserId,
    this._drive,
    this._localMedia,
    this._people,
    this._categories,
  );

  static const _uuid = Uuid();

  // ── getMilestones ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Milestone>>> getMilestones() async {
    try {
      final local = await _local.fetchAll();
      if (local.isNotEmpty) {
        return Right(local.map((c) => c.toDomain()).toList());
      }
      if (!_premium.isPremium) {
        return const Right([]);
      }
      // Premium + empty local → seed from Supabase
      final remoteModels = await _remote.fetchMilestones();
      for (final model in remoteModels) {
        await _local.upsert(
            MilestoneCollection.fromMilestone(model, SyncStatus.synced));
      }
      return Right(List<Milestone>.from(remoteModels));
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncFromCloud() async {
    if (!_premium.isPremium) return const Right(null);
    try {
      final remoteModels = await _remote.fetchMilestones();
      for (final model in remoteModels) {
        await _local.upsert(MilestoneCollection.fromMilestone(
          model,
          SyncStatus.synced,
        ));
      }
      return const Right(null);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── getMilestoneById ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Milestone>> getMilestoneById(String id) async {
    try {
      final local = await _local.fetchById(id);
      if (local != null) return Right(local.toDomain());
      if (!_premium.isPremium) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }
      final model = await _remote.fetchMilestoneById(id);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── createMilestone ────────────────────────────────────────────────────────

  @override
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
  }) async {
    final userId = _getUserId();
    final categoryName = await _resolveCategoryName(categoryId) ?? 'General';

    final extracted = TextMetadataExtractor.extract(userNote);
    final tags = extracted.hashtags;
    final participantIds = await _resolveParticipantIds(extracted.mentions);

    if (!_premium.isPremium) {
      return _saveLocalOnly(
        title: (title == null || title.trim().isEmpty)
            ? _dateTitle(eventDate)
            : title.trim(),
        description: userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        categoryId: categoryId,
        participants: participants,
        participantIds: participantIds,
        tags: tags,
        isPublic: isPublic,
        driveFileId: driveFileId,
        localMediaPaths: localMediaPaths,
        localMediaTypes: localMediaTypes,
      );
    }

    // Premium path — try remote, fall back to local on any error
    String? aiTitle;
    String? narrative;
    try {
      final bio = await _remote.callBiographerNarrative(
        userNote: userNote,
        date: eventDate,
        location: locationName,
        imageBase64: imageBase64,
      );
      aiTitle = bio.title;
      narrative = bio.narrative;

      final chosenTitle = (title == null || title.trim().isEmpty)
          ? aiTitle
          : title.trim();

      final insertData = MilestoneModel.toInsertMap(
        title: chosenTitle,
        description: narrative,
        participants: participants,
        participantIds: participantIds,
        tags: tags,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: categoryName,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
      final remoteModel = await _remote.insertMilestone(insertData);
      final collection =
          MilestoneCollection.fromMilestone(remoteModel, SyncStatus.synced);
      if (localMediaPaths.isNotEmpty) {
        try {
          final items = await _persistLocalMediaItems(
            date: eventDate,
            milestoneId: remoteModel.id,
            paths: localMediaPaths,
            types: localMediaTypes,
          );
          collection.mediaItems = items.map(MediaItemEmbed.fromDomain).toList();
        } catch (_) {
          // Best-effort local media persistence.
        }
      }
      await _local.upsert(collection);

      // Post-local upsert to Supabase (premium). Best-effort.
      try {
        await _remote.upsertMilestone(
          remoteModel.id,
          MilestoneModel.toInsertMap(
            title: remoteModel.title,
            description: remoteModel.description,
            participants: participants,
            participantIds: participantIds,
            tags: tags,
            eventDate: eventDate,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            category: categoryName,
            isPublic: isPublic,
            driveFileId: driveFileId,
          ),
        );
      } catch (_) {
        // Best-effort upsert.
      }

      return Right(remoteModel);
    } catch (_) {
      return _saveLocalOnly(
        title: (title == null || title.trim().isEmpty)
            ? (aiTitle ?? _dateTitle(eventDate))
            : title.trim(),
        description: narrative ?? userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        categoryId: categoryId,
        participants: participants,
        participantIds: participantIds,
        tags: tags,
        isPublic: isPublic,
        driveFileId: driveFileId,
        localMediaPaths: localMediaPaths,
        localMediaTypes: localMediaTypes,
      );
    }
  }

  // ── deleteMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteMilestone(
    String id, {
    String? accessToken,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      await _local.deleteById(id);

      if (existing != null) {
        try {
          await _localMedia.deleteFolder(existing.eventDate, id);
        } catch (_) {
          // Best-effort local media cleanup.
        }
      }

      if (_premium.isPremium) {
        try {
          await _remote.deleteMilestone(id);
        } catch (_) {
          // Best-effort Supabase delete.
        }

        if (accessToken != null && existing != null) {
          final ids = <String>{
            if (existing.driveFileId != null) existing.driveFileId!,
            for (final mi in existing.mediaItems)
              if (mi.driveFileId != null) mi.driveFileId!,
          };
          for (final fid in ids) {
            try {
              await _drive.deleteFile(fileId: fid, accessToken: accessToken);
            } catch (_) {
              // Best-effort Google Drive delete.
            }
          }
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── updateMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Milestone>> updateMilestone({
    required String id,
    required String title,
    required String description,
    int? categoryId,
    DateTime? eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      if (existing == null) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }

      final extracted = TextMetadataExtractor.extract(description);
      final tags = extracted.hashtags;
      final participantIds = await _resolveParticipantIds(extracted.mentions);

      existing
        ..title = title
        ..description = description
        ..participants = participantIds
        ..tags = tags
        ..syncStatus = SyncStatus.pending;
      if (eventDate != null) existing.eventDate = eventDate;
      if (locationName != null) existing.locationName = locationName;
      if (latitude != null) existing.latitude = latitude;
      if (longitude != null) existing.longitude = longitude;
      if (categoryId != null) existing.categoryId = categoryId;
      await _local.upsert(existing);

      if (_premium.isPremium) {
        try {
          final categoryName = categoryId == null
              ? null
              : await _resolveCategoryName(categoryId);
          final updateData = MilestoneModel.toUpdateMap(
            title: title,
            description: description,
            eventDate: eventDate,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            participantIds: existing.participants,
            tags: existing.tags,
            category: categoryName,
          );
          final remoteModel = await _remote.updateMilestone(id, updateData);
          await _local.upsert(MilestoneCollection.fromMilestone(
              remoteModel, SyncStatus.synced));
          return Right(remoteModel);
        } catch (_) {
          // Remote failed — already saved locally as pending
        }
      }

      // Post-local upsert to Supabase (premium). Best-effort.
      if (_premium.isPremium) {
        try {
          final categoryName = await _resolveCategoryName(existing.categoryId);
          await _remote.upsertMilestone(
            existing.id,
            MilestoneModel.toInsertMap(
              title: existing.title,
              description: existing.description,
              participants: const [],
              participantIds: existing.participants,
              tags: existing.tags,
              eventDate: existing.eventDate,
              locationName: existing.locationName,
              latitude: existing.latitude,
              longitude: existing.longitude,
              category: categoryName ?? 'General',
              isPublic: existing.isPublic,
              driveFileId: existing.driveFileId,
            ),
          );
        } catch (_) {
          // Best-effort upsert.
        }
      }

      return Right(existing.toDomain());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Either<Failure, Milestone>> _saveLocalOnly({
    required String title,
    required String? description,
    required String userId,
    required DateTime eventDate,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required int categoryId,
    required List<String> participants,
    required List<String> participantIds,
    required List<String> tags,
    required bool isPublic,
    required String? driveFileId,
    required List<String> localMediaPaths,
    required List<MediaType> localMediaTypes,
  }) async {
    try {
      final milestoneId = _uuid.v4();
      final collection = MilestoneCollection()
        ..id = milestoneId
        ..userId = userId
        ..title = title
        ..description = description
        ..participants = List<String>.from(participantIds)
        ..tags = List<String>.from(tags)
        ..eventDate = eventDate
        ..locationName = locationName
        ..latitude = latitude
        ..longitude = longitude
        ..categoryId = categoryId
        ..isPublic = isPublic
        ..createdAt = DateTime.now()
        ..driveFileId = driveFileId
        ..syncStatus = SyncStatus.pending
        ..media = [];

      if (localMediaPaths.isNotEmpty) {
        final items = await _persistLocalMediaItems(
          date: eventDate,
          milestoneId: milestoneId,
          paths: localMediaPaths,
          types: localMediaTypes,
        );
        collection.mediaItems = items.map(MediaItemEmbed.fromDomain).toList();
      }
      final saved = await _local.upsert(collection);

      return Right(saved.toDomain());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<String?> _resolveCategoryName(int categoryId) async {
    try {
      final c = await _categories.fetchById(categoryId);
      return c?.name;
    } catch (_) {
      return null;
    }
  }

  Future<List<MediaItem>> _persistLocalMediaItems({
    required DateTime date,
    required String milestoneId,
    required List<String> paths,
    required List<MediaType> types,
  }) async {
    final out = <MediaItem>[];

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final type = i < types.length ? types[i] : MediaType.image;

      final destPath = await _localMedia.moveFileToMilestoneFolder(
        date: date,
        milestoneId: milestoneId,
        sourcePath: path,
      );
      if (destPath == null) continue;

      if (type == MediaType.video) {
        final thumbPath = await _localMedia.generateVideoThumbnail(
          date: date,
          milestoneId: milestoneId,
          videoPath: destPath,
        );
        out.add(
          MediaItem(
            localPath: destPath,
            thumbnailPath: thumbPath ?? destPath,
            mediaType: MediaType.video,
            isSynced: false,
          ),
        );
      } else {
        out.add(
          MediaItem(
            localPath: destPath,
            thumbnailPath: destPath,
            mediaType: MediaType.image,
            isSynced: false,
          ),
        );
      }
    }

    return out;
  }

  Future<List<String>> _resolveParticipantIds(List<String> mentions) async {
    final ids = <String>[];
    for (final mention in mentions) {
      final normalized = _toTitleCase(mention);
      final existing = await _people.fetchByName(normalized);
      if (existing != null) {
        ids.add(existing.id);
        continue;
      }

      final personId = _uuid.v4();
      await _people.upsert(
        PersonCollection.fromEntity(
          Person(
            id: personId,
            name: normalized,
          ),
        ),
      );
      ids.add(personId);
    }
    return ids;
  }

  static String _toTitleCase(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.length == 1) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String _dateTitle(DateTime date) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return 'Hito del ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
