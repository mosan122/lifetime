import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';

part 'people_state.dart';

class PeopleCubit extends Cubit<PeopleState> {
  PeopleCubit(
    this._personDs,
    this._cloudSync,
    this._faceCropper,
  ) : super(const PeopleLoading());

  final IsarPersonDataSource _personDs;
  final CloudSyncService _cloudSync;
  final FaceCropperService _faceCropper;
  int _refreshEpoch = 0;

  /// Restaura caras desde la nube (best-effort) y recarga la lista desde Isar.
  Future<void> bootstrap() async {
    emit(const PeopleLoading());
    try {
      await _cloudSync.restoreMissingFaces();
    } catch (_) {
      // Best-effort; la lista local sigue siendo la fuente de verdad.
    }
    await reload();
  }

  /// Recarga personas desde Isar y emite [PeopleLoaded] (nueva instancia de lista).
  Future<void> reload() async {
    final raw = await _personDs.fetchAll();
    emit(PeopleLoaded(
      List<PersonCollection>.from(raw),
      refreshEpoch: ++_refreshEpoch,
    ));
  }

  /// Persiste la cara recortada y vuelve a leer Isar para refrescar la UI.
  Future<Either<Failure, Unit>> saveCroppedFaceForPerson({
    required String personId,
    required File croppedFile,
  }) async {
    final result = await _faceCropper.saveForPerson(
      personId: personId,
      croppedFile: croppedFile,
    );
    return await result.fold<Future<Either<Failure, Unit>>>(
      (f) async => Left(f),
      (_) async {
        await reload();
        return const Right(unit);
      },
    );
  }
}
