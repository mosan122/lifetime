import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/local_media_store.dart';
import 'data/services/face_cropper_service_impl.dart';
import 'domain/services/face_cropper_service.dart';
import 'core/services/local_media_store_web.dart'
    if (dart.library.io) 'core/services/local_media_store_io.dart'
    as local_media_store_factory;
import 'core/services/location_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/cleanup_service.dart';
import 'core/services/space_cleanup_service.dart';
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
import 'features/milestones/data/datasources/isar_person_datasource.dart';
import 'features/milestones/data/datasources/isar_category_datasource.dart';
import 'features/milestones/data/models/local/milestone_collection.dart';
import 'features/milestones/data/models/local/category_collection.dart';
import 'features/milestones/data/models/local/person_collection.dart';
import 'features/profile/data/datasources/profile_remote_datasource.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
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
/// Call once in main() after Supabase.initialize().
Future<void> init() async {
  // ─── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<LocalMediaStore>(
    () => local_media_store_factory.createLocalMediaStore(),
  );
  // google_sign_in v7 uses a singleton instance + explicit initialize().
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '242729475593-oc3pa4loinraaj19af4tali8kur61hqe.apps.googleusercontent.com',
  );

  // ─── Isar (local DB) — native only ───────────────────────────────────────
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    Isar? isar;
    var isarEnabled = true;
    var peopleEnabled = true;
    try {
      isar = await Isar.open(
        [MilestoneCollectionSchema, PersonCollectionSchema, CategoryCollectionSchema],
        name: 'lifetime',
        directory: dir.path,
      );
    } on IsarError {
      // `isar_generator` v3 is pinned to analyzer<6 which can be incompatible
      // with newer Flutter SDK toolchains. In that case we may ship with
      // partially-generated schemas (e.g. people). Fall back to opening only
      // the milestones collection so the app can boot.
      final existing = Isar.getInstance('lifetime') ?? Isar.getInstance();
      await existing?.close();
      try {
        isar = await Isar.open(
          [MilestoneCollectionSchema, CategoryCollectionSchema],
          name: 'lifetime',
          directory: dir.path,
        );
        peopleEnabled = false;
      } on IsarError {
        // Last resort: disable Isar completely (keep app bootable).
        isarEnabled = false;
      }
    }
    if (isarEnabled && isar != null) {
      sl.registerLazySingleton<Isar>(() => isar!);
      sl.registerLazySingleton<IsarMilestoneDataSource>(
        () => IsarMilestoneDataSourceImpl(sl()),
      );
      sl.registerLazySingleton<IsarPersonDataSource>(
        () => peopleEnabled
            ? IsarPersonDataSourceImpl(sl())
            : _WebPersonDataSource(),
      );
      sl.registerLazySingleton<IsarCategoryDataSource>(
        () => IsarCategoryDataSourceImpl(sl()),
      );
    } else {
      sl.registerLazySingleton<IsarMilestoneDataSource>(
        () => _WebMilestoneDataSource(),
      );
      sl.registerLazySingleton<IsarPersonDataSource>(
        () => _WebPersonDataSource(),
      );
      sl.registerLazySingleton<IsarCategoryDataSource>(
        () => _WebCategoryDataSource(),
      );
    }
  } else {
    sl.registerLazySingleton<IsarMilestoneDataSource>(
      () => _WebMilestoneDataSource(),
    );
    sl.registerLazySingleton<IsarPersonDataSource>(
      () => _WebPersonDataSource(),
    );
    sl.registerLazySingleton<IsarCategoryDataSource>(
      () => _WebCategoryDataSource(),
    );
  }

  // ─── Services ─────────────────────────────────────────────────────────────
  final premiumService = PremiumService();
  await premiumService.init();
  sl.registerLazySingleton<PremiumService>(() => premiumService);
  // Note: DriveApi is constructed per-sync with fresh auth headers.
  sl.registerLazySingleton<CloudSyncService>(
    () => CloudSyncService(sl(), sl<GoogleSignIn>(), sl<IsarMilestoneDataSource>(), sl<IsarPersonDataSource>()),
  );
  sl.registerLazySingleton<CleanupService>(
    () => CleanupService(sl<PremiumService>(), sl<IsarMilestoneDataSource>()),
  );
  sl.registerLazySingleton<SpaceCleanupService>(
    () => SpaceCleanupService(sl<PremiumService>(), sl<IsarMilestoneDataSource>()),
  );
  sl.registerLazySingleton<FaceCropperService>(
    () => FaceCropperServiceImpl(personDs: sl<IsarPersonDataSource>()),
  );

  // ─── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRemoteDataSource>(
    () => MilestoneRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl(), sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl()),
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
      sl<DriveRepository>(),
      sl<LocalMediaStore>(),
      sl<IsarPersonDataSource>(),
      sl<IsarCategoryDataSource>(),
    ),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl(), sl()),
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
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl(), sl(), sl(), sl()));

  // ─── Local seeds ──────────────────────────────────────────────────────────
  try {
    await sl<IsarCategoryDataSource>().ensureSeeded();
  } catch (_) {
    // Best-effort seed; app remains usable without it.
  }

  // ─── Cleanup policy (Premium) ─────────────────────────────────────────────
  try {
    await sl<CleanupService>().runIfDue();
  } catch (_) {
    // Best-effort cleanup; never block startup.
  }

  // ─── Space cleanup (Premium) ──────────────────────────────────────────────
  try {
    await sl<SpaceCleanupService>().runCleanup();
  } catch (_) {
    // Best-effort cleanup; never block startup.
  }
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
  Future<void> markMediaItemSynced({
    required String milestoneId,
    required String localPath,
    required String driveFileId,
  }) async {
    final item = _store.where((e) => e.id == milestoneId).firstOrNull;
    if (item == null) return;
    final idx = item.mediaItems.indexWhere((m) => m.localPath == localPath);
    if (idx < 0) return;
    item.mediaItems[idx]
      ..isSynced = true
      ..driveFileId = driveFileId;
  }

  @override
  Future<void> setDriveFolderId({
    required String milestoneId,
    required String driveFolderId,
  }) async {
    final item = _store.where((e) => e.id == milestoneId).firstOrNull;
    if (item == null) return;
    item.driveFolderId = driveFolderId;
  }

  @override
  Future<List<MilestoneCollection>> fetchPending() async =>
      _store.where((c) => c.syncStatus == SyncStatus.pending).toList();
}

class _WebPersonDataSource implements IsarPersonDataSource {
  final List<PersonCollection> _store = [];

  @override
  Future<PersonCollection?> fetchByName(String name) async {
    final needle = name.trim().toLowerCase();
    return _store
        .where((p) => p.name.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  @override
  Future<PersonCollection?> fetchById(String id) async =>
      _store.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<PersonCollection>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final wanted = ids.toSet();
    return _store.where((p) => wanted.contains(p.id)).toList();
  }

  @override
  Future<List<PersonCollection>> fetchAll() async => List.unmodifiable(_store);

  @override
  Future<PersonCollection> upsert(PersonCollection c) async {
    final existingIndex = _store.indexWhere((e) => e.id == c.id);
    if (existingIndex != -1) {
      _store[existingIndex] = c;
    } else {
      _store.add(c);
    }
    return c;
  }

  @override
  Future<void> deleteById(String id) async =>
      _store.removeWhere((e) => e.id == id);
}

class _WebCategoryDataSource implements IsarCategoryDataSource {
  final List<CategoryCollection> _store = [];
  var _seeded = false;

  @override
  Future<void> ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;
    if (_store.isNotEmpty) return;
    _store.addAll([
      _seed(name: 'General', iconName: 'category', colorValue: 0xFF9E9E9E),
      _seed(name: 'Cumpleaños', iconName: 'cake', colorValue: 0xFFFFC1CC),
      _seed(name: 'Boda', iconName: 'favorite', colorValue: 0xFFF48FB1),
      _seed(name: 'Nacimiento', iconName: 'child_care', colorValue: 0xFF4DB6AC),
      _seed(name: 'Especial', iconName: 'star', colorValue: 0xFFFFD54F),
    ]);
  }

  @override
  Future<List<CategoryCollection>> fetchAll() async {
    await ensureSeeded();
    final sorted = [..._store]..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<CategoryCollection?> fetchById(int id) async {
    await ensureSeeded();
    return _store.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<CategoryCollection?> fetchByName(String name) async {
    await ensureSeeded();
    return _store
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }

  @override
  Future<CategoryCollection> upsert(CategoryCollection c) async {
    await ensureSeeded();
    final existing = await fetchByName(c.name);
    if (existing != null) {
      c.id = existing.id;
      c.isSystem = existing.isSystem;
      _store.remove(existing);
      _store.add(c);
      return c;
    }
    c.id = (_store.map((e) => e.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    _store.add(c);
    return c;
  }

  @override
  Future<void> deleteById(int id) async {
    await ensureSeeded();
    final existing = await fetchById(id);
    if (existing == null) return;
    if (existing.isSystem) return;
    _store.remove(existing);
  }

  static CategoryCollection _seed({
    required String name,
    required String iconName,
    required int colorValue,
  }) {
    return CategoryCollection()
      ..id = (_tmpId++)
      ..name = name
      ..iconName = iconName
      ..colorValue = colorValue
      ..isSystem = true;
  }
}

int _tmpId = 1;
