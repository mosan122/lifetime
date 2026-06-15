import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/failures/failure.dart';
import '../../domain/repositories/drive_repository.dart';
import '../datasources/google_drive_datasource.dart';

class DriveRepositoryImpl implements DriveRepository {
  final GoogleDriveDataSource _datasource;

  const DriveRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, String>> uploadMedia({
    required File file,
    required String accessToken,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final id = await _datasource.uploadMedia(
        file: file,
        accessToken: accessToken,
        mimeType: mimeType,
      );
      return Right(id);
    } on DriveQuotaExceededException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveUploadTimeoutException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getThumbnailLink({
    required String fileId,
    required String accessToken,
  }) async {
    try {
      final url = await _datasource.getThumbnailLink(
        fileId: fileId,
        accessToken: accessToken,
      );
      return Right(url);
    } on DriveQuotaExceededException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveUploadTimeoutException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFile({
    required String fileId,
    required String accessToken,
  }) async {
    try {
      await _datasource.deleteFile(fileId: fileId, accessToken: accessToken);
      return const Right(null);
    } on DriveQuotaExceededException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveUploadTimeoutException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } on DriveException catch (e) {
      return Left(NetworkFailure(e.message, e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
