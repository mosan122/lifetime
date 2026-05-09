import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/failures/failure.dart';
import '../../domain/entities/user_profile_details.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remote;
  final SupabaseClient _supabase;

  const ProfileRepositoryImpl(this._remote, this._supabase);

  @override
  Future<Either<Failure, UserProfileDetails>> fetchUserProfile({
    required String userId,
    required String emailFallback,
  }) async {
    try {
      var row = await _remote.fetchProfileRow(userId);
      if (row == null) {
        try {
          await _supabase.from('profiles').insert({
            'id': userId,
            'is_premium': false,
          });
        } catch (_) {}
        row = await _remote.fetchProfileRow(userId);
      }
      if (row == null) {
        return Right(
          UserProfileDetails(
            userId: userId,
            email: emailFallback,
            displayName: '',
            isPremium: false,
          ),
        );
      }
      return Right(
        ProfileRemoteDataSourceImpl.rowToDetails(
          userId,
          emailFallback,
          row,
        ),
      );
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

  @override
  Future<Either<Failure, UserProfileDetails>> saveUserProfile({
    required UserProfileDetails details,
    Uint8List? newAvatarBytes,
  }) async {
    try {
      var avatarUrl = details.avatarUrl;
      if (newAvatarBytes != null && newAvatarBytes.isNotEmpty) {
        final uploaded = await _uploadAvatar(details.userId, newAvatarBytes);
        if (uploaded != null) {
          avatarUrl = uploaded;
        }
      }
      final merged = details.copyWith(avatarUrl: avatarUrl);
      await _remote.updateProfileFields(
        userId: merged.userId,
        displayName: merged.displayName,
        firstName: merged.firstName,
        lastName: merged.lastName,
        birthDate: merged.birthDate,
        avatarUrl: merged.avatarUrl,
      );
      final row = await _remote.fetchProfileRow(merged.userId);
      if (row == null) return Right(merged);
      return Right(
        ProfileRemoteDataSourceImpl.rowToDetails(
          merged.userId,
          merged.email,
          row,
        ),
      );
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  Future<String?> _uploadAvatar(String userId, Uint8List bytes) async {
    try {
      final path = '$userId/avatar.jpg';
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return _supabase.storage.from('avatars').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
