import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_profile_details.dart';

class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();
}

abstract class ProfileRemoteDataSource {
  Future<bool> fetchIsPremium(String userId);
  Future<String?> fetchUserIdByEmail(String email);
  Future<bool> upsertProfileAfterLogin({
    required String userId,
    required String email,
    required DateTime lastConnection,
  });

  /// Fila completa de `profiles` o null si no existe.
  Future<Map<String, dynamic>?> fetchProfileRow(String userId);

  Future<void> updateProfileFields({
    required String userId,
    required String displayName,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? avatarUrl,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  const ProfileRemoteDataSourceImpl(this._supabase);

  @override
  Future<bool> fetchIsPremium(String userId) async {
    final row = await fetchProfileRow(userId);
    if (row == null) throw const ProfileNotFoundException();
    final value = row['is_premium'];
    return value == true;
  }

  @override
  Future<String?> fetchUserIdByEmail(String email) async {
    final v = email.trim().toLowerCase();
    if (v.isEmpty) return null;
    final row = await _supabase
        .from('profiles')
        .select('id')
        .eq('email', v)
        .maybeSingle();
    if (row == null) return null;
    final id = row['id'];
    return (id is String && id.trim().isNotEmpty) ? id : null;
  }

  @override
  Future<bool> upsertProfileAfterLogin({
    required String userId,
    required String email,
    required DateTime lastConnection,
  }) async {
    bool existingPremium = false;
    try {
      existingPremium = await fetchIsPremium(userId);
    } on ProfileNotFoundException {
      existingPremium = false;
    }

    await _supabase.from('profiles').upsert(
      {
        'id': userId,
        'email': email,
        'last_connection': lastConnection.toIso8601String(),
        'is_premium': existingPremium,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'id',
    );

    return existingPremium;
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileRow(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      rethrow;
    }
  }

  @override
  Future<void> updateProfileFields({
    required String userId,
    required String displayName,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? avatarUrl,
  }) async {
    final fn = firstName?.trim();
    final ln = lastName?.trim();
    final av = avatarUrl?.trim();
    final map = <String, dynamic>{
      'display_name': displayName.trim(),
      'first_name': (fn == null || fn.isEmpty) ? null : fn,
      'last_name': (ln == null || ln.isEmpty) ? null : ln,
      'avatar_url': (av == null || av.isEmpty) ? null : av,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (birthDate != null) {
      map['birth_date'] =
          '${birthDate.year.toString().padLeft(4, '0')}-'
          '${birthDate.month.toString().padLeft(2, '0')}-'
          '${birthDate.day.toString().padLeft(2, '0')}';
    }
    await _supabase.from('profiles').update(map).eq('id', userId);
  }

  static UserProfileDetails rowToDetails(
    String userId,
    String emailFallback,
    Map<String, dynamic> row,
  ) {
    final email = (row['email'] as String?)?.trim() ?? emailFallback;
    final display =
        (row['display_name'] as String?)?.trim() ?? '';
    final first = (row['first_name'] as String?)?.trim();
    final last = (row['last_name'] as String?)?.trim();
    DateTime? birth;
    final bd = row['birth_date'];
    if (bd is String && bd.isNotEmpty) {
      birth = DateTime.tryParse(bd);
    }
    final avatar = (row['avatar_url'] as String?)?.trim();
    final premium = row['is_premium'] == true;
    return UserProfileDetails(
      userId: userId,
      email: email,
      displayName: display,
      firstName: first?.isEmpty ?? true ? null : first,
      lastName: last?.isEmpty ?? true ? null : last,
      birthDate: birth,
      avatarUrl: avatar?.isEmpty ?? true ? null : avatar,
      isPremium: premium,
    );
  }
}
