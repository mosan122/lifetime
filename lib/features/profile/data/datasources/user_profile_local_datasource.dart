import 'package:isar/isar.dart';

import '../../domain/entities/user_profile_details.dart';
import '../models/local/user_profile_collection.dart';

abstract class UserProfileLocalDataSource {
  Future<UserProfileDetails?> getByUserId(String userId);
  /// Ruta en disco del avatar guardado localmente (`UserProfileCollection.localAvatarPath`).
  Future<String?> getLocalAvatarPath(String userId);
  /// Actualiza solo la ruta local del avatar (p. ej. tras copiar a disco).
  Future<void> patchLocalAvatarPath(String userId, String path);
  Future<void> patchGoogleDriveLink({
    required String userId,
    required bool linked,
    String? accountEmail,
  });
  Future<void> patchIsPremium({
    required String userId,
    required bool isPremium,
  });
  Future<void> put(UserProfileDetails details);
}

class NoOpUserProfileLocalDataSource implements UserProfileLocalDataSource {
  @override
  Future<UserProfileDetails?> getByUserId(String userId) async => null;

  @override
  Future<String?> getLocalAvatarPath(String userId) async => null;

  @override
  Future<void> patchLocalAvatarPath(String userId, String path) async {}

  @override
  Future<void> patchGoogleDriveLink({
    required String userId,
    required bool linked,
    String? accountEmail,
  }) async {}

  @override
  Future<void> patchIsPremium({
    required String userId,
    required bool isPremium,
  }) async {}

  @override
  Future<void> put(UserProfileDetails details) async {}
}

class IsarUserProfileLocalDataSourceImpl implements UserProfileLocalDataSource {
  IsarUserProfileLocalDataSourceImpl(this._isar);

  final Isar _isar;

  @override
  Future<UserProfileDetails?> getByUserId(String userId) async {
    final row = await _isar.userProfileCollections.getByUserId(userId);
    if (row == null) return null;
    return UserProfileDetails(
      userId: row.userId,
      email: '',
      displayName: row.displayName,
      firstName: row.firstName,
      lastName: row.lastName,
      birthDate: row.birthDate,
      avatarUrl: row.avatarUrl,
      isPremium: row.isPremium,
      googleDriveLinked: row.googleDriveLinked,
      googleDriveAccountEmail: row.googleDriveAccountEmail,
    );
  }

  @override
  Future<String?> getLocalAvatarPath(String userId) async {
    final row = await _isar.userProfileCollections.getByUserId(userId);
    final p = row?.localAvatarPath?.trim();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  @override
  Future<void> patchLocalAvatarPath(String userId, String path) async {
    final row = await _isar.userProfileCollections.getByUserId(userId);
    if (row == null) return;
    row.localAvatarPath = path;
    await _isar.writeTxn(() async {
      await _isar.userProfileCollections.put(row);
    });
  }

  @override
  Future<void> patchGoogleDriveLink({
    required String userId,
    required bool linked,
    String? accountEmail,
  }) async {
    final existing = await _isar.userProfileCollections.getByUserId(userId);
    if (existing == null) return;
    existing.googleDriveLinked = linked;
    if (linked) {
      final email = accountEmail?.trim();
      if (email != null && email.isNotEmpty) {
        existing.googleDriveAccountEmail = email;
      }
    } else {
      existing.googleDriveAccountEmail = null;
    }
    await _isar.writeTxn(() async {
      await _isar.userProfileCollections.put(existing);
    });
  }

  @override
  Future<void> patchIsPremium({
    required String userId,
    required bool isPremium,
  }) async {
    var row = await _isar.userProfileCollections.getByUserId(userId);
    row ??= UserProfileCollection()
      ..userId = userId
      ..displayName = '';
    row.isPremium = isPremium;
    await _isar.writeTxn(() async {
      await _isar.userProfileCollections.putByUserId(row!);
    });
  }

  @override
  Future<void> put(UserProfileDetails d) async {
    final existing = await _isar.userProfileCollections.getByUserId(d.userId);
    final row = UserProfileCollection()
      ..userId = d.userId
      ..displayName = d.displayName
      ..firstName = d.firstName
      ..lastName = d.lastName
      ..birthDate = d.birthDate
      ..avatarUrl = d.avatarUrl
      ..localAvatarPath = existing?.localAvatarPath
      ..googleDriveLinked = d.googleDriveLinked
      ..googleDriveAccountEmail = d.googleDriveAccountEmail
      ..isPremium = d.isPremium;
    await _isar.writeTxn(() async {
      await _isar.userProfileCollections.putByUserId(row);
    });
  }
}
