import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/failures/failure.dart';

abstract class DriveRepository {
  Future<Either<Failure, String>> uploadMedia({
    required File file,
    required String accessToken,
    String mimeType = 'application/octet-stream',
  });

  Future<Either<Failure, String>> getThumbnailLink({
    required String fileId,
    required String accessToken,
  });

  Future<Either<Failure, void>> deleteFile({
    required String fileId,
    required String accessToken,
  });
}
