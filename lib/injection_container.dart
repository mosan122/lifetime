import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/location_service.dart';
import 'core/services/premium_service.dart';
import 'data/datasources/google_drive_datasource.dart';
import 'data/datasources/isar_milestone_datasource.dart';
import 'data/datasources/milestone_remote_datasource.dart';
import 'data/repositories/drive_repository_impl.dart';
import 'data/repositories/milestone_repository_impl.dart';
import 'domain/repositories/drive_repository.dart';
import 'domain/repositories/milestone_repository.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/milestones/data/models/local/milestone_collection.dart';
import 'features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'features/milestones/domain/usecases/delete_milestone_usecase.dart';
import 'features/milestones/domain/usecases/export_bitacora_usecase.dart';
import 'features/milestones/domain/usecases/get_media_thumbnail_usecase.dart';
import 'features/milestones/domain/usecases/get_milestones_usecase.dart';
import 'features/milestones/domain/usecases/update_milestone_usecase.dart';
import 'features/milestones/domain/usecases/upload_media_usecase.dart';
import 'features/milestones/presentation/bloc/create_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/delete_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/edit_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/map_cubit.dart';
import 'features/milestones/presentation/bloc/milestone_timeline_cubit.dart';
import 'features/settings/presentation/bloc/export_cubit.dart';

final sl = GetIt.instance;

// Web OAuth client ID — only needed on web (mobile reads from google-services.json).
const _googleWebClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

/// Call once in main() after Supabase.initialize().
Future<void> init() async {
  // ─── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(
      clientId: kIsWeb ? _googleWebClientId : null,
      scopes: ['https://www.googleapis.com/auth/drive.file'],
    ),
  );

  // ─── Isar (local DB) — native only ───────────────────────────────────────
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [MilestoneCollectionSchema],
      directory: dir.path,
    );
    sl.registerLazySingleton<Isar>(() => isar);
    sl.registerLazySingleton<IsarMilestoneDataSource>(
      () => IsarMilestoneDataSourceImpl(sl()),
    );
  } else {
    sl.registerLazySingleton<IsarMilestoneDataSource>(
      () => _WebMilestoneDataSource(),
    );
  }

  // ─── Services ─────────────────────────────────────────────────────────────
  final premiumService = PremiumService();
  await premiumService.init();
  sl.registerLazySingleton<PremiumService>(() => premiumService);

  // ─── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRemoteDataSource>(
    () => MilestoneRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl(), sl()),
  );
  sl.registerLazySingleton<GoogleDriveDataSource>(
    () => GoogleDriveDataSourceImpl(sl()),
  );

  // ─── Repositories ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRepository>(
    () => MilestoneRepositoryImpl(
      sl<IsarMilestoneDataSource>(),
      sl<MilestoneRemoteDataSource>(),
      sl<PremiumService>(),
      () => Supabase.instance.client.auth.currentUser?.id ?? '',
    ),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<DriveRepository>(
    () => DriveRepositoryImpl(sl()),
  );

  // ─── Use Cases ────────────────────────────────────────────────────────────
  sl.registerFactory<CreateMilestoneUseCase>(() => CreateMilestoneUseCase(sl()));
  sl.registerFactory<GetMilestonesUseCase>(() => GetMilestonesUseCase(sl()));
  sl.registerFactory<UploadMediaUseCase>(() => UploadMediaUseCase(sl()));
  sl.registerFactory<GetMediaThumbnailUseCase>(
      () => GetMediaThumbnailUseCase(sl()));
  sl.registerFactory<DeleteMilestoneUseCase>(() => DeleteMilestoneUseCase(sl()));
  sl.registerFactory<UpdateMilestoneUseCase>(() => UpdateMilestoneUseCase(sl()));
  sl.registerFactory<ExportBitacoraUseCase>(() => ExportBitacoraUseCase(sl()));

  // ─── Cubits ───────────────────────────────────────────────────────────────
  sl.registerFactory<MilestoneTimelineCubit>(() => MilestoneTimelineCubit(sl()));
  sl.registerFactory<CreateMilestoneCubit>(() => CreateMilestoneCubit(sl(), sl()));
  sl.registerFactory<EditMilestoneCubit>(() => EditMilestoneCubit(sl()));
  sl.registerFactory<DeleteMilestoneCubit>(() => DeleteMilestoneCubit(sl()));
  sl.registerFactory<ExportCubit>(() => ExportCubit(sl()));
  sl.registerFactory<MapCubit>(() => MapCubit(sl()));
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl(), sl()));
}

// In-memory fallback used on web (Isar requires native FFI, unavailable in JS).
class _WebMilestoneDataSource implements IsarMilestoneDataSource {
  final List<MilestoneCollection> _store = [];

  @override
  Future<List<MilestoneCollection>> fetchAll() async {
    final sorted = [..._store]
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return sorted;
  }

  @override
  Future<MilestoneCollection?> fetchById(String id) async =>
      _store.where((c) => c.id == id).firstOrNull;

  @override
  Future<MilestoneCollection> upsert(MilestoneCollection c) async {
    _store.removeWhere((e) => e.id == c.id);
    _store.add(c);
    return c;
  }

  @override
  Future<void> deleteById(String id) async =>
      _store.removeWhere((e) => e.id == id);

  @override
  Future<void> markSynced(String id) async {
    final item = _store.where((e) => e.id == id).firstOrNull;
    if (item != null) item.syncStatus = SyncStatus.synced;
  }

  @override
  Future<List<MilestoneCollection>> fetchPending() async =>
      _store.where((c) => c.syncStatus == SyncStatus.pending).toList();
}
