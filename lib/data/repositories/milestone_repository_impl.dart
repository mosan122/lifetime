// lib/data/repositories/milestone_repository_impl.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/failures/failure.dart';
import '../../core/utils/milestone_title_utils.dart';
import '../../core/services/local_media_store.dart';
import '../../core/services/text_metadata_extractor.dart';
import '../../core/services/premium_service.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/drive_repository.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/isar_milestone_datasource.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import '../../features/milestones/data/models/local/media_asset_embed.dart';
import '../../features/milestones/data/models/local/media_item_embed.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final IsarMilestoneDataSource _local;
  final MilestoneRemoteDataSource _remote;
  final PremiumService _premium;
  final String Function() _getUserId;
  final DriveRepository _drive;
  final LocalMediaStore _localMedia;

  MilestoneRepositoryImpl(
    this._local,
    this._remote,
    this._premium,
    this._getUserId,
    this._drive,
    this._localMedia,
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
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    String? categoryId,
    List<String> participants = const [],
    bool isPublic = false,
    String? driveFileId,
    String? imageBase64,
    List<String> localMediaPaths = const [],
    List<MediaType> localMediaTypes = const [],
  }) async {
    final userId = _getUserId();
    final safeCategoryId = (categoryId == null || categoryId.trim().isEmpty)
        ? 'otros'
        : categoryId.trim().toLowerCase();

    final extracted = TextMetadataExtractor.extract(userNote);
    final tags = extracted.hashtags;
    final participantIds = _dedupeParticipantIds(participants);

    if (!_premium.isPremium) {
      return _saveLocalOnly(
        title: (title == null || title.trim().isEmpty)
            ? milestoneFallbackTitleFromDescription(userNote)
            : title.trim(),
        description: userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        locationCity: locationCity,
        locationCountry: locationCountry,
        latitude: latitude,
        longitude: longitude,
        categoryId: safeCategoryId,
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
          ? (bio.title.trim().isNotEmpty
              ? bio.title.trim()
              : milestoneFallbackTitleFromDescription(userNote))
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
        categoryId: safeCategoryId,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
      final remoteModel = await _remote.insertMilestone(insertData);
      final collection =
          MilestoneCollection.fromMilestone(remoteModel, SyncStatus.synced);
      if (locationName != null &&
          locationName.trim().isNotEmpty &&
          (latitude != null && longitude != null)) {
        collection.location = MilestoneLocationDataEmbed()
          ..name = locationName.trim()
          ..city = (locationCity?.trim().isEmpty ?? true)
              ? null
              : locationCity?.trim()
          ..country = (locationCountry?.trim().isEmpty ?? true)
              ? null
              : locationCountry?.trim()
          ..latitude = latitude
          ..longitude = longitude;
      } else if (locationName != null && locationName.trim().isNotEmpty) {
        collection.location = MilestoneLocationDataEmbed()
          ..name = locationName.trim()
          ..city = (locationCity?.trim().isEmpty ?? true)
              ? null
              : locationCity?.trim()
          ..country = (locationCountry?.trim().isEmpty ?? true)
              ? null
              : locationCountry?.trim()
          ..latitude = latitude
          ..longitude = longitude;
      }
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
            categoryId: safeCategoryId,
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
            ? ((aiTitle != null && aiTitle.trim().isNotEmpty)
                ? aiTitle.trim()
                : milestoneFallbackTitleFromDescription(userNote))
            : title.trim(),
        description: narrative ?? userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        locationCity: locationCity,
        locationCountry: locationCountry,
        latitude: latitude,
        longitude: longitude,
        categoryId: safeCategoryId,
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
    String? categoryId,
    DateTime? eventDate,
    String? locationName,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    List<String> participantIds = const [],
    List<MediaItem> mediaToKeep = const [],
    List<File> newMediaFiles = const [],
    List<MediaType> newMediaTypes = const [],
    int? galleryCoverIndex,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      if (existing == null) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }

      final extracted = TextMetadataExtractor.extract(description);
      final tags = extracted.hashtags;
      final resolvedIds = _dedupeParticipantIds(participantIds);

      final dateForPaths = eventDate ?? existing.eventDate;
      final newPersistedItems = newMediaFiles.isEmpty
          ? <MediaItem>[]
          : await _persistLocalMediaItems(
              date: dateForPaths,
              milestoneId: existing.id,
              paths: newMediaFiles.map((f) => f.path).toList(),
              types: newMediaTypes,
            );
      final newEmbeds =
          newPersistedItems.map(MediaItemEmbed.fromDomain).toList();

      existing
        ..title = title
        ..description = description
        ..participants = resolvedIds
        ..tags = tags
        ..mediaItems = [
          ...mediaToKeep.map(MediaItemEmbed.fromDomain),
          ...newEmbeds,
        ]
        ..syncStatus = SyncStatus.pending;
      if (galleryCoverIndex != null) {
        existing.galleryCoverIndex = galleryCoverIndex;
      }
      _clampGalleryCoverIndex(existing);
      if (eventDate != null) existing.eventDate = eventDate;
      if (locationName != null) existing.locationName = locationName;
      if (latitude != null) existing.latitude = latitude;
      if (longitude != null) existing.longitude = longitude;
      if (locationName != null ||
          locationCity != null ||
          locationCountry != null ||
          latitude != null ||
          longitude != null) {
        final prev = existing.location;
        final name = locationName ?? prev?.name ?? existing.locationName;
        final lat = latitude ?? prev?.latitude ?? existing.latitude;
        final lon = longitude ?? prev?.longitude ?? existing.longitude;
        existing.location = (name == null || name.trim().isEmpty) &&
                lat == null &&
                lon == null
            ? null
            : (MilestoneLocationDataEmbed()
              ..name = name
              ..city = locationCity ?? prev?.city
              ..country = locationCountry ?? prev?.country
              ..latitude = lat
              ..longitude = lon);
      }
      if (categoryId != null) existing.categoryId = categoryId;
      await _local.upsert(existing);

      if (_premium.isPremium) {
        try {
          final safeCategoryId =
              categoryId == null ? null : categoryId.trim().toLowerCase();
          final updateData = MilestoneModel.toUpdateMap(
            title: title,
            description: description,
            eventDate: eventDate,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            participantIds: existing.participants,
            tags: existing.tags,
            categoryId: safeCategoryId,
          );
          final remoteModel = await _remote.updateMilestone(id, updateData);
          final prevLoc = existing.location;
          existing
            ..title = remoteModel.title
            ..description = remoteModel.description
            ..eventDate = remoteModel.eventDate
            ..locationName = remoteModel.locationName
            ..latitude = remoteModel.latitude
            ..longitude = remoteModel.longitude
            ..categoryId = remoteModel.categoryId
            ..participants = List<String>.from(remoteModel.participantIds)
            ..tags = List<String>.from(remoteModel.tags)
            ..isPublic = remoteModel.isPublic
            ..driveFileId = remoteModel.driveFileId
            ..media = remoteModel.media
                .map(MediaAssetEmbed.fromEntity)
                .toList()
            ..syncStatus = SyncStatus.synced;
          final name = remoteModel.locationName ?? prevLoc?.name;
          final lat = remoteModel.latitude ?? prevLoc?.latitude;
          final lon = remoteModel.longitude ?? prevLoc?.longitude;
          existing.location = (name == null || name.trim().isEmpty) &&
                  lat == null &&
                  lon == null
              ? null
              : (MilestoneLocationDataEmbed()
                ..name = name
                ..city = prevLoc?.city
                ..country = prevLoc?.country
                ..latitude = lat
                ..longitude = lon);
          await _local.upsert(existing);
          return Right(existing.toDomain());
        } catch (_) {
          // Remote failed — already saved locally as pending
        }
      }

      // Post-local upsert to Supabase (premium). Best-effort.
      if (_premium.isPremium) {
        try {
          final safeCategoryId = (existing.categoryId == null ||
                  existing.categoryId!.trim().isEmpty)
              ? 'otros'
              : existing.categoryId!.trim().toLowerCase();
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
              categoryId: safeCategoryId,
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

  @override
  Future<Either<Failure, Milestone>> setGalleryCoverIndex({
    required String id,
    required int index,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      if (existing == null) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }
      final n = existing.mediaItems.length;
      if (n == 0) {
        return Left(DatabaseFailure('El hito no tiene medios'));
      }
      existing.galleryCoverIndex = index.clamp(0, n - 1);
      existing.syncStatus = SyncStatus.pending;
      await _local.upsert(existing);
      return Right(existing.toDomain());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  void _clampGalleryCoverIndex(MilestoneCollection c) {
    final n = c.mediaItems.length;
    if (n <= 0) {
      c.galleryCoverIndex = 0;
    } else if (c.galleryCoverIndex < 0) {
      c.galleryCoverIndex = 0;
    } else if (c.galleryCoverIndex >= n) {
      c.galleryCoverIndex = n - 1;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Either<Failure, Milestone>> _saveLocalOnly({
    required String title,
    required String? description,
    required String userId,
    required DateTime eventDate,
    required String? locationName,
    required String? locationCity,
    required String? locationCountry,
    required double? latitude,
    required double? longitude,
    required String categoryId,
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
        ..location = (() {
          final name = locationName;
          final lat = latitude;
          final lon = longitude;
          if ((name == null || name.trim().isEmpty) && lat == null && lon == null) {
            return null;
          }
          final city = (locationCity?.trim().isEmpty ?? true)
              ? null
              : locationCity?.trim();
          final country = (locationCountry?.trim().isEmpty ?? true)
              ? null
              : locationCountry?.trim();
          return MilestoneLocationDataEmbed()
            ..name = name
            ..city = city
            ..country = country
            ..latitude = lat
            ..longitude = lon;
        })()
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

  static List<String> _dedupeParticipantIds(List<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      final t = id.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

}
