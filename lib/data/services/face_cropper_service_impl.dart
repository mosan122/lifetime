import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/failures/failure.dart';
import '../../domain/entities/person.dart';
import '../../domain/services/face_cropper_service.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/models/local/person_collection.dart';

class FaceCropperServiceImpl implements FaceCropperService {
  final ImagePicker _picker;
  final ImageCropper _cropper;
  final IsarPersonDataSource _personDs;

  FaceCropperServiceImpl({
    required IsarPersonDataSource personDs,
    ImagePicker? picker,
    ImageCropper? cropper,
  })  : _personDs = personDs,
        _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  @override
  Future<Either<Failure, File>> pickAndCrop({
    required FaceImageSource source,
    String? milestoneImagePath,
  }) async {
    try {
      File inputFile;

      if (source == FaceImageSource.milestoneImage) {
        assert(milestoneImagePath != null,
            'milestoneImagePath required for milestoneImage source');
        inputFile = File(milestoneImagePath!);
      } else {
        final xFile = await _picker.pickImage(
          source: source == FaceImageSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        if (xFile == null) return const Left(FaceCropCancelledFailure());
        inputFile = File(xFile.path);
      }

      // In image_cropper v12, cropStyle is set inside platform UI settings
      final croppedFile = await _cropper.cropImage(
        sourcePath: inputFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            toolbarColor: const Color(0xFF000080),
            toolbarWidgetColor: const Color(0xFFF5F5DC),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            hidesNavigationBar: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) return const Left(FaceCropCancelledFailure());
      return Right(File(croppedFile.path));
    } catch (_) {
      return const Left(FaceCropPickFailure());
    }
  }

  @override
  Future<Either<Failure, Person>> saveForPerson({
    required String personId,
    required File croppedFile,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final facesDir = Directory('${appDir.path}/faces');
      if (!facesDir.existsSync()) await facesDir.create(recursive: true);

      final destPath = '${facesDir.path}/$personId.jpg';
      await croppedFile.copy(destPath);

      final existing = await _personDs.fetchById(personId);
      if (existing == null) return const Left(FaceCropSaveFailure());

      final updated = PersonCollection()
        ..isarId = existing.isarId
        ..id = existing.id
        ..name = existing.name
        ..faceImagePath = destPath
        ..driveFaceFileId = null;

      final saved = await _personDs.upsert(updated);
      return Right(saved.toDomain());
    } catch (_) {
      return const Left(FaceCropSaveFailure());
    }
  }
}
