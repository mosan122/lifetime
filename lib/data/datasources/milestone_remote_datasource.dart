import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/milestone_model.dart';

typedef BiographerResult = ({String title, String narrative});

abstract class MilestoneRemoteDataSource {
  Future<BiographerResult> callBiographerNarrative({
    required String userNote,
    required DateTime date,
    String? location,
  });

  Future<MilestoneModel> insertMilestone(Map<String, dynamic> data);
  Future<List<MilestoneModel>> fetchMilestones();
  Future<MilestoneModel> fetchMilestoneById(String id);
}

class MilestoneRemoteDataSourceImpl implements MilestoneRemoteDataSource {
  final SupabaseClient _supabase;

  const MilestoneRemoteDataSourceImpl(this._supabase);

  @override
  Future<BiographerResult> callBiographerNarrative({
    required String userNote,
    required DateTime date,
    String? location,
  }) async {
    final response = await _supabase.functions.invoke(
      'biographer-narrative',
      body: {
        'metadata': {
          'date': date.toIso8601String(),
          if (location != null) 'location': location,
        },
        'userNote': userNote,
      },
    );

    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected biographer response format');
    }
    final data = response.data as Map<String, dynamic>;
    final title = data['title'] as String?;
    final narrative = data['narrative'] as String?;

    if (title == null || narrative == null) {
      throw const FormatException('Missing title or narrative in biographer response');
    }

    return (title: title, narrative: narrative);
  }

  @override
  Future<MilestoneModel> insertMilestone(Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const AuthException('No authenticated user');
    final userId = user.id;
    final response = await _supabase
        .from('milestones')
        .insert({...data, 'user_id': userId})
        .select('*, media_assets(*)')
        .single();
    return MilestoneModel.fromJson(response);
  }

  @override
  Future<List<MilestoneModel>> fetchMilestones() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const AuthException('No authenticated user');
    final userId = user.id;
    final response = await _supabase
        .from('milestones')
        .select('*, media_assets(*)')
        .eq('user_id', userId)
        .order('event_date', ascending: false);
    return response.map(MilestoneModel.fromJson).toList();
  }

  @override
  Future<MilestoneModel> fetchMilestoneById(String id) async {
    final response = await _supabase
        .from('milestones')
        .select('*, media_assets(*)')
        .eq('id', id)
        .single();
    return MilestoneModel.fromJson(response);
  }
}
