import 'package:isar/isar.dart';

part 'user_profile_collection.g.dart';

@Collection()
class UserProfileCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String userId;

  late String displayName;
  String? firstName;
  String? lastName;
  DateTime? birthDate;
  String? avatarUrl;
  String? localAvatarPath;

  /// Cuenta Google vinculada solo para Drive (email/Apple + linkGoogleAccount).
  bool googleDriveLinked = false;
  String? googleDriveAccountEmail;

  bool isPremium = false;
}
