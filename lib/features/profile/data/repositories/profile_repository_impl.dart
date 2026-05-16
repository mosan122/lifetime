import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/notifiers/people_faces_revision_notifier.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../domain/entities/user_profile_details.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../datasources/user_profile_local_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(
    this._remote,
    this._supabase,
    this._personDs,
    this._profileLocal,
    this._facesRevision,
  );

  final ProfileRemoteDataSource _remote;
  final SupabaseClient _supabase;
  final IsarPersonDataSource _personDs;
  final UserProfileLocalDataSource _profileLocal;
  final PeopleFacesRevisionNotifier _facesRevision;

  @override
  Future<Either<Failure, UserProfileDetails>> fetchUserProfile({
    required String userId,
    required String emailFallback,
  }) async {
    try {
      var row = await _remote.fetchProfileRow(userId);
      if (row == null) {
        try {
          await _supabase.from('profiles').insert({
            'id': userId,
            'is_premium': false,
          });
        } catch (_) {}
        row = await _remote.fetchProfileRow(userId);
      }
      if (row == null) {
        return Right(
          UserProfileDetails(
            userId: userId,
            email: emailFallback,
            displayName: '',
            isPremium: false,
          ),
        );
      }
      return Right(
        ProfileRemoteDataSourceImpl.rowToDetails(
          userId,
          emailFallback,
          row,
        ),
      );
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> upsertProfileAfterLogin({
    required String userId,
    required String email,
  }) async {
    try {
      final existingPremium = await _remote.upsertProfileAfterLogin(
        userId: userId,
        email: email,
        lastConnection: DateTime.now(),
      );
      return Right(existingPremium);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserProfileDetails>> saveUserProfile({
    required UserProfileDetails details,
    Uint8List? newAvatarBytes,
  }) async {
    try {
      var avatarUrl = details.avatarUrl;
      if (newAvatarBytes != null && newAvatarBytes.isNotEmpty) {
        final upload = await _uploadAvatar(details.userId, newAvatarBytes);
        if (upload.url == null) {
          final hint = upload.error?.trim();
          return Left(
            NetworkFailure(_avatarUploadFailureMessage(hint)),
          );
        }
        avatarUrl = upload.url;
      }
      final merged = UserProfileDetails(
        userId: details.userId,
        email: details.email,
        displayName: details.displayName,
        firstName: details.firstName,
        lastName: details.lastName,
        birthDate: details.birthDate,
        avatarUrl: avatarUrl,
        isPremium: details.isPremium,
      );
      await _remote.updateProfileFields(
        userId: merged.userId,
        displayName: merged.displayName,
        firstName: merged.firstName,
        lastName: merged.lastName,
        birthDate: merged.birthDate,
        avatarUrl: merged.avatarUrl,
      );
      final row = await _remote.fetchProfileRow(merged.userId);
      final out = row == null
          ? merged
          : ProfileRemoteDataSourceImpl.rowToDetails(
              merged.userId,
              merged.email,
              row,
            );

      final avatarChanged = (newAvatarBytes != null && newAvatarBytes.isNotEmpty) ||
          (details.avatarUrl ?? '').trim() != (out.avatarUrl ?? '').trim();
      if (avatarChanged) {
        await _syncLinkedPersonFaceFromProfile(
          userId: out.userId,
          newAvatarBytes: newAvatarBytes,
          avatarUrl: out.avatarUrl,
        );
      }

      return Right(out);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  /// Actualiza `faces/{personId}.jpg` de la persona con [linkedUserId] = [userId]
  /// para que hitos existentes muestren la nueva foto.
  Future<void> _syncLinkedPersonFaceFromProfile({
    required String userId,
    Uint8List? newAvatarBytes,
    String? avatarUrl,
  }) async {
    if (kIsWeb) return;
    final person = await _personDs.fetchByLinkedUserId(userId);
    if (person == null) return;

    final bytes = newAvatarBytes;
    final hasNewBytes = bytes != null && bytes.isNotEmpty;
    final url = avatarUrl?.trim() ?? '';
    if (!hasNewBytes && url.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final facesDir = Directory('${appDir.path}/faces');
    if (!facesDir.existsSync()) await facesDir.create(recursive: true);
    final destPath = '${facesDir.path}/${person.id}.jpg';

    try {
      if (bytes != null && bytes.isNotEmpty) {
        await File(destPath).writeAsBytes(bytes, flush: true);
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
          return;
        }
        final res = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 ||
            res.statusCode >= 300 ||
            res.bodyBytes.isEmpty) {
          return;
        }
        await File(destPath).writeAsBytes(res.bodyBytes, flush: true);
      }
    } catch (e, st) {
      developer.log(
        'sync linked person face skipped',
        name: 'ProfileRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return;
    }

    PaintingBinding.instance.imageCache.evict(FileImage(File(destPath)));

    final updated = person.copyScalars()
      ..faceImagePath = destPath
      ..driveFaceFileId = person.driveFaceFileId;
    await _personDs.upsert(updated);
    await _profileLocal.patchLocalAvatarPath(userId, destPath);
    _facesRevision.bump();
  }

  /// Mensaje legible: bucket ausente (404) vs RLS vs otros.
  String _avatarUploadFailureMessage(String? rawError) {
    final r = rawError ?? '';
    if (r.contains('Bucket not found') ||
        r.contains('bucket not found') ||
        (r.contains('404') && r.toLowerCase().contains('bucket'))) {
      return 'Falta el bucket de avatares en Supabase (error «Bucket not found»).\n\n'
          '1) Dashboard → Storage → New bucket: id **avatars**, público, '
          'tipos imagen jpeg/png/webp.\n'
          '   O ejecuta el SQL: **supabase/migrations/20260509120100_storage_avatars_bucket.sql**\n'
          '2) Luego las políticas: **20260509120300_avatars_storage_rls_fix.sql**';
    }
    final lower = r.toLowerCase();
    if (lower.contains('row-level security') ||
        lower.contains('rls') ||
        r.contains('403')) {
      return 'Storage bloqueó la subida (RLS). Ejecuta en Supabase:\n'
          '**supabase/migrations/20260509120300_avatars_storage_rls_fix.sql**\n\n'
          'Detalle: $r';
    }
    if (r.isEmpty) {
      return 'No se pudo subir la foto. Revisa conexión, bucket **avatars** '
          '(migración 201) y políticas (migración 203).';
    }
    return 'No se pudo subir la foto.\n\n$r\n\n'
        'Si acabas de crear el proyecto: ejecuta primero '
        '**20260509120100_storage_avatars_bucket.sql** y después **20260509120300_avatars_storage_rls_fix.sql**.';
  }

  Future<({String? url, String? error})> _uploadAvatar(
    String userId,
    Uint8List bytes,
  ) async {
    try {
      final kind = _avatarContentTypeAndExt(bytes);
      final path = '$userId/avatar.${kind.$2}';
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: kind.$1,
            ),
          );
      final base = _supabase.storage.from('avatars').getPublicUrl(path);
      final v = DateTime.now().millisecondsSinceEpoch;
      final url = base.contains('?') ? '$base&v=$v' : '$base?v=$v';
      return (url: url, error: null);
    } catch (e, st) {
      developer.log(
        'upload avatar failed',
        name: 'ProfileRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return (url: null, error: e.toString());
    }
  }

  /// (contentType, extensión sin punto)
  (String, String) _avatarContentTypeAndExt(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ('image/jpeg', 'jpg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return ('image/png', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return ('image/webp', 'webp');
    }
    return ('image/jpeg', 'jpg');
  }
}
