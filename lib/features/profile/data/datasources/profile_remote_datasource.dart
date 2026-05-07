import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();
}

abstract class ProfileRemoteDataSource {
  Future<bool> fetchIsPremium(String userId);
  Future<bool> upsertProfileAfterLogin({
    required String userId,
    required String email,
    required DateTime lastConnection,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  const ProfileRemoteDataSourceImpl(this._supabase);

  @override
  Future<bool> fetchIsPremium(String userId) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select('is_premium')
          .eq('id', userId)
          .single();

      final value = row['is_premium'];
      return value == true;
    } on PostgrestException catch (e) {
      // PGRST116: "Results contain 0 rows" (no profile yet)
      if (e.code == 'PGRST116') {
        throw const ProfileNotFoundException();
      }
      rethrow;
    }
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
      },
      onConflict: 'id',
    );

    return existingPremium;
  }
}

