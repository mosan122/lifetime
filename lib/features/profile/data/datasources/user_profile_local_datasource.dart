import 'package:isar/isar.dart';

import '../../domain/entities/user_profile_details.dart';
import '../models/local/user_profile_collection.dart';

abstract class UserProfileLocalDataSource {
  Future<UserProfileDetails?> getByUserId(String userId);
  Future<void> put(UserProfileDetails details);
}

class NoOpUserProfileLocalDataSource implements UserProfileLocalDataSource {
  @override
  Future<UserProfileDetails?> getByUserId(String userId) async => null;

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
      isPremium: false,
    );
  }

  @override
  Future<void> put(UserProfileDetails d) async {
    final row = UserProfileCollection()
      ..userId = d.userId
      ..displayName = d.displayName
      ..firstName = d.firstName
      ..lastName = d.lastName
      ..birthDate = d.birthDate
      ..avatarUrl = d.avatarUrl
      ..localAvatarPath = null;
    await _isar.writeTxn(() async {
      await _isar.userProfileCollections.putByUserId(row);
    });
  }
}
