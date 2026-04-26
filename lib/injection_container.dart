import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/datasources/milestone_remote_datasource.dart';
import 'data/repositories/milestone_repository_impl.dart';
import 'domain/repositories/milestone_repository.dart';
import 'features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'features/milestones/domain/usecases/get_milestones_usecase.dart';
import 'features/milestones/presentation/bloc/milestone_timeline_cubit.dart';

final sl = GetIt.instance;

/// Call once in main() after Supabase.initialize().
Future<void> init() async {
  // ─── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // ─── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRemoteDataSource>(
    () => MilestoneRemoteDataSourceImpl(sl()),
  );

  // ─── Repositories ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRepository>(
    () => MilestoneRepositoryImpl(sl()),
  );

  // ─── Use Cases ────────────────────────────────────────────────────────────
  sl.registerFactory<CreateMilestoneUseCase>(() => CreateMilestoneUseCase(sl()));
  sl.registerFactory<GetMilestonesUseCase>(() => GetMilestonesUseCase(sl()));

  // ─── Cubits ───────────────────────────────────────────────────────────────
  sl.registerFactory<MilestoneTimelineCubit>(() => MilestoneTimelineCubit(sl()));
}
