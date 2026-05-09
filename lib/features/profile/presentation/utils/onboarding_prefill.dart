import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/user_profile_details.dart';

/// Valores iniciales del onboarding a partir de sesión OAuth / metadatos Supabase.
UserProfileDetails onboardingInitialFromAuth({
  required AuthUser user,
  required bool isPremium,
}) {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
  final given = (meta['given_name'] as String?)?.trim();
  final family = (meta['family_name'] as String?)?.trim();
  final nick = user.displayName?.trim() ??
      (meta['name'] as String?)?.trim() ??
      (meta['full_name'] as String?)?.trim() ??
      '';
  String? first = given;
  String? last = family;
  if ((first == null || first.isEmpty) &&
      (last == null || last.isEmpty) &&
      nick.contains(' ')) {
    final parts = nick.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      first = parts.first;
      last = parts.sublist(1).join(' ');
    }
  }
  final pic = user.photoUrl ??
      (meta['avatar_url'] as String?)?.trim() ??
      (meta['picture'] as String?)?.trim();

  return UserProfileDetails(
    userId: user.id,
    email: user.email,
    displayName: nick,
    firstName: first?.isEmpty ?? true ? null : first,
    lastName: last?.isEmpty ?? true ? null : last,
    birthDate: null,
    avatarUrl: pic?.isEmpty ?? true ? null : pic,
    isPremium: isPremium,
  );
}
