import 'package:equatable/equatable.dart';

/// Perfil editable del usuario (Supabase `profiles` + caché Isar).
class UserProfileDetails extends Equatable {
  final String userId;
  final String email;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? avatarUrl;
  final bool isPremium;

  const UserProfileDetails({
    required this.userId,
    required this.email,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.avatarUrl,
    this.isPremium = false,
  });

  bool get needsOnboarding => displayName.trim().isEmpty;

  UserProfileDetails copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? avatarUrl,
    bool? isPremium,
  }) {
    return UserProfileDetails(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  List<Object?> get props =>
      [userId, email, displayName, firstName, lastName, birthDate, avatarUrl, isPremium];
}
