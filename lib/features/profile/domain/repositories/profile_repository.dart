import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/failures/failure.dart';
import '../entities/user_profile_details.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserProfileDetails>> fetchUserProfile({
    required String userId,
    required String emailFallback,
  });

  Future<Either<Failure, bool>> upsertProfileAfterLogin({
    required String userId,
    required String email,
  });

  /// Actualiza `profiles` y opcionalmente sube un nuevo avatar a Storage (`avatars`).
  Future<Either<Failure, UserProfileDetails>> saveUserProfile({
    required UserProfileDetails details,
    Uint8List? newAvatarBytes,
  });
}
