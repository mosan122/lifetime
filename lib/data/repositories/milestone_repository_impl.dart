import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/failures/failure.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final MilestoneRemoteDataSource _datasource;

  const MilestoneRepositoryImpl(this._datasource);

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
  }) async {
    try {
      final result = await _datasource.callBiographerNarrative(
        userNote: userNote,
        date: eventDate,
        location: locationName,
      );

      final insertData = MilestoneModel.toInsertMap(
        title: result.title,
        description: result.narrative,
        participants: participants,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        isPublic: isPublic,
      );

      final model = await _datasource.insertMilestone(insertData);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } on FunctionException catch (e) {
      return Left(NetworkFailure(e.details?.toString() ?? 'Edge Function error'));
    } on FormatException {
      return const Left(BiographerFailure());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Milestone>>> getMilestones() async {
    try {
      final models = await _datasource.fetchMilestones();
      return Right(models);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Milestone>> getMilestoneById(String id) async {
    try {
      final model = await _datasource.fetchMilestoneById(id);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
