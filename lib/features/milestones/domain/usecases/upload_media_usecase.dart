import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/repositories/drive_repository.dart';

class UploadMediaUseCase implements UseCase<String, UploadMediaParams> {
  final DriveRepository repository;

  const UploadMediaUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(UploadMediaParams params) {
    return repository.uploadMedia(
      file: params.file,
      accessToken: params.accessToken,
      mimeType: params.mimeType,
    );
  }
}

class UploadMediaParams extends Equatable {
  final File file;
  final String accessToken;
  final String mimeType;

  const UploadMediaParams({
    required this.file,
    required this.accessToken,
    this.mimeType = 'application/octet-stream',
  });

  @override
  List<Object?> get props => [file, accessToken, mimeType];
}
