import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/failures/failure.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remote;
  final SupabaseClient _supabase;

  const ProfileRepositoryImpl(this._remote, this._supabase);

  @override
  Future<Either<Failure, Profile>> fetchProfile(String userId) async {
    try {
      final isPremium = await _remote.fetchIsPremium(userId);
      return Right(Profile(id: userId, isPremium: isPremium));
    } on ProfileNotFoundException {
      // Best-effort fallback: if trigger isn't installed yet, create a row.
      try {
        await _supabase.from('profiles').insert({
          'id': userId,
          'is_premium': false,
        });
      } catch (_) {}
      return Right(Profile(id: userId, isPremium: false));
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> upsertProfileAfterLogin({
    required String userId,
    required String email,
  }) async {
    try {
      final existingPremium = await _remote.upsertProfileAfterLogin(
        userId: userId,
        email: email,
        lastConnection: DateTime.now(),
      );
      return Right(existingPremium);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}

