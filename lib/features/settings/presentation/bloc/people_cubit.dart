import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/notifiers/people_faces_revision_notifier.dart';
import '../../../../core/utils/person_ui_filters.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/datasources/isar_relationship_datasource.dart';
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';

part 'people_state.dart';

class PeopleCubit extends Cubit<PeopleState> {
  PeopleCubit(
    this._personDs,
    this._personGroupDs,
    this._milestoneDs,
    this._relationshipDs,
    this._premium,
    this._cloudSync,
    this._faceCropper,
    this._profileRemote,
  ) : super(const PeopleLoading());

  final IsarPersonDataSource _personDs;
  final PersonGroupLocalDataSource _personGroupDs;
  final IsarMilestoneDataSource _milestoneDs;
  final IsarRelationshipDataSource _relationshipDs;
  final PremiumService _premium;
  final CloudSyncService _cloudSync;
  final FaceCropperService _faceCropper;
  final ProfileRemoteDataSource _profileRemote;
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
    await _personGroupDs.ensureSeededAndMigrateLegacy(_personDs);
    final raw = await _personDs.fetchAll();
    final map = await _personGroupDs.buildPersonIdToGroupIds();
    for (final p in raw) {
      p.runtimeGroupIds = List<String>.from(map[p.id] ?? const []);
    }
    final groups = await _personGroupDs.fetchAllGroupsOrdered();
    final forUi = withoutLinkedCurrentUser(raw);
    emit(PeopleLoaded(
      List<PersonCollection>.from(forUi),
      List<GroupCollection>.from(groups),
      refreshEpoch: ++_refreshEpoch,
    ));
    if (sl.isRegistered<PeopleFacesRevisionNotifier>()) {
      sl<PeopleFacesRevisionNotifier>().bump();
    }
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

  /// Borra la persona local, sus vínculos y la quita de los hitos. No permite
  /// eliminar la ficha vinculada a la cuenta actual.
  Future<Either<Failure, Unit>> deletePerson(String personId) async {
    final id = personId.trim();
    if (id.isEmpty) {
      return const Left(DatabaseFailure('Persona no válida.'));
    }

    final person = await _personDs.fetchById(id);
    if (person == null) {
      return const Left(DatabaseFailure('No se encontró la persona.'));
    }

    final authId = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (authId.isNotEmpty && (person.linkedUserId ?? '').trim() == authId) {
      return const Left(
        DatabaseFailure(
          'No puedes eliminar tu propia ficha. Gestiona tu perfil en Ajustes → Mi perfil.',
        ),
      );
    }

    try {
      final milestoneCount =
          await _milestoneDs.countMilestonesContainingPerson(id);
      if (milestoneCount > 0) {
        final label = person.name.trim().isNotEmpty ? person.name.trim() : id;
        return Left(
          DatabaseFailure(
            'No se puede eliminar a «$label» porque aparece en '
            '$milestoneCount hito${milestoneCount == 1 ? '' : 's'}. '
            'Quítala de esos hitos antes de borrarla.',
          ),
        );
      }

      final soft = _premium.isPremium;

      if (sl.isRegistered<IsarRelationshipDataSource>()) {
        await _relationshipDs.deleteAllInvolvingPerson(
          id,
          softDelete: soft,
        );
      }

      if (soft) {
        await _personGroupDs.removeAllMembershipsForPerson(id);
        await _personDs.deleteById(id, softDelete: true);
        await reload();
        return const Right(unit);
      }

      final driveId = person.driveFaceFileId?.trim();
      if (driveId != null && driveId.isNotEmpty) {
        // Best-effort; usuarios básicos sin Drive vinculado.
      }

      final fp = person.faceImagePath?.trim();
      if (fp != null && fp.isNotEmpty) {
        try {
          final file = File(fp);
          if (file.existsSync()) await file.delete();
        } catch (_) {
          // Best-effort.
        }
      }

      await _personGroupDs.removeAllMembershipsForPerson(id);
      await _personDs.deleteById(id);
      await reload();
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, String>> verifyLifeTimeEmail(String email) async {
    try {
      final id = await _profileRemote.fetchUserIdByEmail(email);
      if (id == null) {
        return Left(DatabaseFailure('No existe un usuario con ese email.'));
      }
      return Right(id);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
