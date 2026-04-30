import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();
}

abstract class ProfileRemoteDataSource {
  Future<bool> fetchIsPremium(String userId);
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
}

