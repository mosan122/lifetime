// lib/data/repositories/milestone_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/failures/failure.dart';
import '../../core/services/premium_service.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/isar_milestone_datasource.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final IsarMilestoneDataSource _local;
  final MilestoneRemoteDataSource _remote;
  final PremiumService _premium;
  final String Function() _getUserId;

  MilestoneRepositoryImpl(
    this._local,
    this._remote,
    this._premium,
    this._getUserId,
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
  }) async {
    final userId = _getUserId();

    if (!_premium.isPremium) {
      return _saveLocalOnly(
        title: _dateTitle(eventDate),
        description: userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        participants: participants,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
    }

    // Premium path — try remote, fall back to local on any error
    String? title;
    String? narrative;
    try {
      final bio = await _remote.callBiographerNarrative(
        userNote: userNote,
        date: eventDate,
        location: locationName,
        imageBase64: imageBase64,
      );
      title = bio.title;
      narrative = bio.narrative;

      final insertData = MilestoneModel.toInsertMap(
        title: title,
        description: narrative,
        participants: participants,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
      final remoteModel = await _remote.insertMilestone(insertData);
      await _local.upsert(
          MilestoneCollection.fromMilestone(remoteModel, SyncStatus.synced));
      return Right(remoteModel);
    } catch (_) {
      return _saveLocalOnly(
        title: title ?? _dateTitle(eventDate),
        description: narrative ?? userNote,
        userId: userId,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        participants: participants,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
    }
  }

  // ── deleteMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteMilestone(String id) async {
    try {
      await _local.deleteById(id);
      if (_premium.isPremium) {
        try {
          await _remote.deleteMilestone(id);
        } catch (_) {
          // Best-effort remote delete
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
    required String description,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      if (existing == null) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }

      existing
        ..description = description
        ..syncStatus = SyncStatus.pending;
      if (locationName != null) existing.locationName = locationName;
      if (latitude != null) existing.latitude = latitude;
      if (longitude != null) existing.longitude = longitude;
      await _local.upsert(existing);

      if (_premium.isPremium) {
        try {
          final updateData = MilestoneModel.toUpdateMap(
            description: description,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
          );
          final remoteModel = await _remote.updateMilestone(id, updateData);
          await _local.upsert(MilestoneCollection.fromMilestone(
              remoteModel, SyncStatus.synced));
          return Right(remoteModel);
        } catch (_) {
          // Remote failed — already saved locally as pending
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
    required String category,
    required List<String> participants,
    required bool isPublic,
    required String? driveFileId,
  }) async {
    try {
      final collection = MilestoneCollection()
        ..id = _uuid.v4()
        ..userId = userId
        ..title = title
        ..description = description
        ..participants = List<String>.from(participants)
        ..eventDate = eventDate
        ..locationName = locationName
        ..latitude = latitude
        ..longitude = longitude
        ..category = category
        ..isPublic = isPublic
        ..createdAt = DateTime.now()
        ..driveFileId = driveFileId
        ..syncStatus = SyncStatus.pending
        ..media = [];
      final saved = await _local.upsert(collection);
      return Right(saved.toDomain());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  static String _dateTitle(DateTime date) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return 'Hito del ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
