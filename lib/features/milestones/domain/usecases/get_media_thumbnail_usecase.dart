import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/repositories/drive_repository.dart';

class GetMediaThumbnailUseCase
    implements UseCase<String, GetMediaThumbnailParams> {
  final DriveRepository repository;

  const GetMediaThumbnailUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(GetMediaThumbnailParams params) {
    return repository.getThumbnailLink(
      fileId: params.fileId,
      accessToken: params.accessToken,
    );
  }
}

class GetMediaThumbnailParams extends Equatable {
  final String fileId;
  final String accessToken;

  const GetMediaThumbnailParams({
    required this.fileId,
    required this.accessToken,
  });

  @override
  List<Object?> get props => [fileId, accessToken];
}
