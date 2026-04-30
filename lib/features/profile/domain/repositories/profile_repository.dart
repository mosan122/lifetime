import 'package:dartz/dartz.dart';

import '../../../../core/failures/failure.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, Profile>> fetchProfile(String userId);
}

