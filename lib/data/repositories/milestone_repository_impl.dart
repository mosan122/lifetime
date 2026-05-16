// lib/data/repositories/milestone_repository_impl.dart
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/failures/failure.dart';
import '../../core/utils/bitacora_backup_json.dart';
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
import '../../features/milestones/data/datasources/isar_category_datasource.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/datasources/isar_relationship_datasource.dart';
import '../../features/milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../features/milestones/data/datasources/person_group_local_datasource.dart';
import '../../features/milestones/data/models/local/category_collection.dart';
import '../../features/milestones/data/models/local/group_collection.dart';
import '../../features/milestones/data/models/local/person_collection.dart';
import '../../features/milestones/data/models/local/relationship_collection.dart';
import '../../features/milestones/data/models/local/saved_location_collection.dart';
import '../../features/sync/schedule_cloud_sync.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final IsarMilestoneDataSource _local;
  final MilestoneRemoteDataSource _remote;
  final PremiumService _premium;
  final String Function() _getUserId;
  final DriveRepository _drive;
  final LocalMediaStore _localMedia;
  final IsarPersonDataSource _personDs;
  final IsarCategoryDataSource _categoryDs;
  final IsarSavedLocationDataSource _savedLocationDs;
  final IsarRelationshipDataSource _relationshipDs;
  final PersonGroupLocalDataSource _personGroupDs;

  MilestoneRepositoryImpl(
    this._local,
    this._remote,
    this._premium,
    this._getUserId,
    this._drive,
    this._localMedia,
    this._personDs,
    this._categoryDs,
    this._savedLocationDs,
    this._relationshipDs,
    this._personGroupDs,
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
    int? savedLocationId,
    String? locationName,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    String? categoryId,
    List<String> participants = const [],
    List<String> protagonistIds = const [],
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
    final safeProtagonists = _dedupeParticipantIds(protagonistIds)
        .where(participantIds.contains)
        .toList();

    if (!_premium.isPremium) {
      return _saveLocalOnly(
        title: (title == null || title.trim().isEmpty)
            ? milestoneFallbackTitleFromDescription(userNote)
            : title.trim(),
        description: userNote,
        userId: userId,
        eventDate: eventDate,
        savedLocationId: savedLocationId,
        locationName: locationName,
        locationCity: locationCity,
        locationCountry: locationCountry,
        latitude: latitude,
        longitude: longitude,
        categoryId: safeCategoryId,
        participants: participants,
        participantIds: participantIds,
        protagonistIds: safeProtagonists,
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
        protagonistIds: safeProtagonists,
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
            protagonistIds: safeProtagonists,
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
        savedLocationId: savedLocationId,
        locationName: locationName,
        locationCity: locationCity,
        locationCountry: locationCountry,
        latitude: latitude,
        longitude: longitude,
        categoryId: safeCategoryId,
        participants: participants,
        participantIds: participantIds,
        protagonistIds: safeProtagonists,
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
      final premium = _premium.isPremium;
      if (premium) {
        await _local.deleteById(id, softDelete: true);
        scheduleCloudDataSync();
        return const Right(null);
      }

      final existing = await _local.fetchById(id);
      await _local.deleteById(id);

      if (existing != null) {
        try {
          await _localMedia.deleteFolder(existing.eventDate, id);
        } catch (_) {
          // Best-effort local media cleanup.
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
    int? savedLocationId,
    String? locationName,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    List<String> participantIds = const [],
    List<String> protagonistIds = const [],
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
      final safeProtagonists = _dedupeParticipantIds(protagonistIds)
          .where(resolvedIds.contains)
          .toList();

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
        ..protagonists = safeProtagonists
        ..tags = tags
        ..mediaItems = _mergeMediaOnUpdate(
          existing: existing,
          mediaToKeep: mediaToKeep,
          newEmbeds: newEmbeds,
          softDeleteRemoved: _premium.isPremium,
        )
        ..syncStatus = SyncStatus.pending
        ..isSynced = false;
      if (galleryCoverIndex != null) {
        existing.galleryCoverIndex = galleryCoverIndex;
      }
      _clampGalleryCoverIndex(existing);
      if (eventDate != null) existing.eventDate = eventDate;
      existing.savedLocationId = savedLocationId;
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
      scheduleCloudDataSync();

      if (_premium.isPremium) {
        try {
          final safeCategoryId = categoryId?.trim().toLowerCase();
          final updateData = MilestoneModel.toUpdateMap(
            title: title,
            description: description,
            eventDate: eventDate,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            participantIds: existing.participants,
            protagonistIds: existing.protagonists,
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
            ..protagonists = existing.protagonists
            ..tags = List<String>.from(remoteModel.tags)
            ..isPublic = remoteModel.isPublic
            ..driveFileId = remoteModel.driveFileId
            ..media = remoteModel.media
                .map(MediaAssetEmbed.fromEntity)
                .toList()
            ..syncStatus = SyncStatus.synced
            ..isSynced = true
            ..supabaseId = remoteModel.id;
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
              protagonistIds: existing.protagonists,
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
      existing.isSynced = false;
      await _local.upsert(existing);
      scheduleCloudDataSync();
      return Right(existing.toDomain());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> importFromBackupJson(String json) async {
    try {
      final preview = BitacoraBackupJson.parseImportPreview(json);
      final refToIsar = <String, int>{};
      if (!preview.isLegacyMilestonesOnly) {
        await _importBackupSidecars(preview, refToIsar);
      }
      final milestones = BitacoraBackupJson.decodeMilestonesFromPreview(
        preview,
        userId: _getUserId(),
        forceUserId: true,
        savedLocationRefToIsarId: refToIsar.isEmpty ? null : refToIsar,
      );
      var n = 0;
      for (final ms in milestones) {
        final c = MilestoneCollection.fromMilestone(ms, SyncStatus.pending);
        _clampGalleryCoverIndex(c);
        await _local.upsert(c);
        n++;
      }
      return Right(n);
    } on FormatException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<void> _importBackupSidecars(
    BitacoraImportPreview p,
    Map<String, int> refToIsarOut,
  ) async {
    for (final map in p.customCategoriesMaps) {
      final id = (map['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      final name = (map['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final icon = (map['icon_name'] as String?)?.trim();
      if (icon == null || icon.isEmpty) continue;
      final colorVal = map['color_value'];
      final color = colorVal is int
          ? colorVal
          : (colorVal is num)
              ? colorVal.toInt()
              : 0xFF000000;
      final row = CategoryCollection()
        ..id = id
        ..name = name
        ..iconName = icon
        ..colorValue = color;
      await _categoryDs.upsert(row);
    }

    for (final map in p.groupsMaps) {
      final id = (map['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      final name = (map['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final row = GroupCollection()
        ..id = id
        ..name = name
        ..builtIn = map['built_in'] as bool? ?? false;
      await _personGroupDs.upsertGroup(row);
    }

    for (final map in p.peopleMaps) {
      final id = (map['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      final name = (map['name'] as String?)?.trim();
      String? facePath = (map['face_image_path'] as String?)?.trim();
      final embedded = map['face_portrait_base64'];
      final restored = await _persistImportedPersonFaceIfAny(
        personId: id,
        base64Body: embedded,
      );
      if (restored != null && restored.isNotEmpty) {
        facePath = restored;
      }
      final row = PersonCollection()
        ..id = id
        ..name = (name != null && name.isNotEmpty) ? name : id
        ..firstName = (map['first_name'] as String?)?.trim()
        ..lastName = (map['last_name'] as String?)?.trim()
        ..birthDate = _parseOptionalIsoDate(map['birth_date'] as String?)
        ..group = ''
        ..notes = (map['notes'] as String?) ?? ''
        ..linkedUserEmail = (map['linked_user_email'] as String?)?.trim()
        ..linkedUserId = (map['linked_user_id'] as String?)?.trim()
        ..faceImagePath = facePath
        ..driveFaceFileId = (map['drive_face_file_id'] as String?)?.trim();
      await _personDs.upsert(row);
    }

    for (final map in p.savedLocationsMaps) {
      final ref = (map['ref'] as String?)?.trim();
      if (ref == null || ref.isEmpty) continue;
      final locName = (map['name'] as String?)?.trim();
      if (locName == null || locName.isEmpty) continue;
      final row = SavedLocationCollection()
        ..name = locName
        ..city = (map['city'] as String?)?.trim()
        ..country = (map['country'] as String?)?.trim()
        ..latitude = (map['latitude'] as num?)?.toDouble()
        ..longitude = (map['longitude'] as num?)?.toDouble();
      final saved = await _savedLocationDs.upsert(row);
      refToIsarOut[ref] = saved.isarId;
    }

    for (final map in p.personGroupLinksMaps) {
      final pid = (map['person_id'] as String?)?.trim();
      final gid = (map['group_id'] as String?)?.trim();
      if (pid == null || gid == null) continue;
      await _personGroupDs.putPersonGroupLinkForImport(pid, gid);
    }

    for (final map in p.relationshipsMaps) {
      final id = (map['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      final personId = (map['person_id'] as String?)?.trim();
      final relatedId = (map['related_person_id'] as String?)?.trim();
      if (personId == null || relatedId == null) continue;
      final type = (map['relationship_type'] as String?)?.trim();
      if (type == null || type.isEmpty) continue;
      final row = RelationshipCollection()
        ..id = id
        ..personId = personId
        ..relatedPersonId = relatedId
        ..relationshipType = type
        ..startDate = _parseOptionalIsoDate(map['start_date'] as String?)
        ..endDate = _parseOptionalIsoDate(map['end_date'] as String?)
        ..isCurrent = map['is_current'] as bool? ?? true;
      await _relationshipDs.put(row);
    }
  }

  static DateTime? _parseOptionalIsoDate(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  /// Decodifica [face_portrait_base64] del backup y escribe `faces/<personId>.jpg`.
  Future<String?> _persistImportedPersonFaceIfAny({
    required String personId,
    Object? base64Body,
  }) async {
    if (base64Body is! String) return null;
    final normalized = base64Body.replaceAll(RegExp(r'\s'), '');
    if (normalized.isEmpty) return null;
    try {
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final facesDir = Directory('${appDir.path}/faces');
      if (!facesDir.existsSync()) {
        await facesDir.create(recursive: true);
      }
      final destPath = '${facesDir.path}/$personId.jpg';
      await File(destPath).writeAsBytes(bytes, flush: true);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  List<MediaItemEmbed> _mergeMediaOnUpdate({
    required MilestoneCollection existing,
    required List<MediaItem> mediaToKeep,
    required List<MediaItemEmbed> newEmbeds,
    required bool softDeleteRemoved,
  }) {
    final keepByPath = {for (final k in mediaToKeep) k.localPath: k};
    final merged = <MediaItemEmbed>[];

    for (final old in existing.mediaItems) {
      if (old.isDeleted) {
        merged.add(old);
        continue;
      }
      final kept = keepByPath.remove(old.localPath);
      if (kept != null) {
        merged.add(MediaItemEmbed.fromDomain(kept)
          ..driveFileId = old.driveFileId ?? kept.driveFileId
          ..isSynced = old.isSynced
          ..isDeleted = false);
      } else if (softDeleteRemoved) {
        merged.add(MediaItemEmbed()
          ..localPath = old.localPath
          ..thumbnailPath = old.thumbnailPath
          ..mediaType = old.mediaType
          ..driveFileId = old.driveFileId
          ..isSynced = false
          ..isDeleted = true);
      }
    }

    for (final kept in keepByPath.values) {
      merged.add(MediaItemEmbed.fromDomain(kept));
    }
    merged.addAll(newEmbeds);
    return merged;
  }

  void _clampGalleryCoverIndex(MilestoneCollection c) {
    final n = c.mediaItems.where((e) => !e.isDeleted).length;
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
    required int? savedLocationId,
    required String? locationName,
    required String? locationCity,
    required String? locationCountry,
    required double? latitude,
    required double? longitude,
    required String categoryId,
    required List<String> participants,
    required List<String> participantIds,
    required List<String> protagonistIds,
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
        ..protagonists = List<String>.from(protagonistIds)
        ..tags = List<String>.from(tags)
        ..eventDate = eventDate
        ..savedLocationId = savedLocationId
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
        ..isSynced = false
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
      scheduleCloudDataSync();

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
