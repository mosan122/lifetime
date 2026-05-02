import 'dart:io';

import 'package:dartz/dartz.dart';

import '../failures/failure.dart';
import '../entities/person.dart';

enum FaceImageSource { gallery, camera, milestoneImage }

abstract class FaceCropperService {
  /// Lanza el picker según [source] y el cropper nativo (circle, 1:1).
  /// Cuando [source] == [FaceImageSource.milestoneImage],
  /// [milestoneImagePath] debe ser no nulo; el picker se omite.
  Future<Either<Failure, File>> pickAndCrop({
    required FaceImageSource source,
    String? milestoneImagePath,
  });

  /// Copia [croppedFile] a <appDocs>/faces/<personId>.jpg,
  /// actualiza faceImagePath en Isar y devuelve la Person actualizada.
  Future<Either<Failure, Person>> saveForPerson({
    required String personId,
    required File croppedFile,
  });
}
