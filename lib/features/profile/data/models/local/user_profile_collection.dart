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
}
