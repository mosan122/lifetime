import 'dart:async';

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
import 'core/services/cloud_sync_status_store.dart';
import 'core/services/bitacora_drive_import_probe.dart';
import 'core/services/drive_milestone_media_restore.dart';
import 'core/services/milestone_drive_media_downloader.dart';
import 'core/services/google_drive_reauth_bridge.dart';
import 'features/sync/data/services/sync_service.dart';
import 'features/sync/presentation/bloc/sync_status_cubit.dart';
import 'core/services/cleanup_service.dart';
import 'core/services/space_cleanup_service.dart';
import 'core/services/premium_service.dart';
import 'core/services/storage_metrics_service.dart';
import 'features/sync/data/services/sync_pending_service.dart';
import 'core/services/milestone_location_resolver.dart';
import 'core/constants/milestone_categories.dart';
import 'core/notifiers/cloud_sync_activity_notifier.dart';
import 'core/notifiers/people_faces_revision_notifier.dart';
import 'core/services/local_user_settings_service.dart';
import 'data/datasources/google_drive_datasource.dart';
import 'data/datasources/isar_milestone_datasource.dart';
import 'data/datasources/milestone_remote_datasource.dart';
import 'data/repositories/drive_repository_impl.dart';
import 'data/repositories/milestone_repository_impl.dart';
import 'domain/repositories/drive_repository.dart';
import 'domain/repositories/milestone_repository.dart';
import 'features/auth/data/datasources/auth_local_persistence.dart';
import 'features/auth/data/models/local/local_user_session_collection.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/services/auth_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/milestones/data/datasources/isar_person_datasource.dart';
import 'features/milestones/data/datasources/isar_category_datasource.dart';
import 'features/milestones/data/datasources/isar_saved_location_datasource.dart';
import 'features/milestones/data/models/local/milestone_collection.dart';
import 'features/milestones/data/models/local/category_collection.dart';
import 'features/milestones/data/models/local/person_collection.dart';
import 'features/milestones/data/models/local/group_collection.dart';
import 'features/milestones/data/models/local/person_group_link_collection.dart';
import 'features/milestones/data/datasources/person_group_local_datasource.dart';
import 'features/milestones/data/models/local/relationship_collection.dart';
import 'features/milestones/data/datasources/isar_relationship_datasource.dart';
import 'features/milestones/domain/services/relationship_service.dart';
import 'features/milestones/data/models/local/saved_location_collection.dart';
import 'features/profile/data/datasources/profile_remote_datasource.dart';
import 'features/profile/data/datasources/user_profile_local_datasource.dart';
import 'features/profile/data/models/local/user_profile_collection.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/milestones/domain/usecases/create_milestone_usecase.dart';
import 'features/milestones/domain/usecases/delete_milestone_usecase.dart';
import 'features/milestones/domain/usecases/export_bitacora_usecase.dart';
import 'features/milestones/domain/usecases/import_bitacora_usecase.dart';
import 'features/milestones/domain/usecases/get_media_thumbnail_usecase.dart';
import 'features/milestones/domain/usecases/get_milestones_usecase.dart';
import 'features/milestones/domain/usecases/update_milestone_usecase.dart';
import 'features/milestones/domain/usecases/upload_media_usecase.dart';
import 'features/milestones/presentation/bloc/create_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/delete_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/edit_milestone_cubit.dart';
import 'features/milestones/presentation/bloc/map_cubit.dart';
import 'features/milestones/presentation/bloc/group_graph_cubit.dart';
import 'features/milestones/presentation/bloc/relationship_tree_cubit.dart';
import 'features/milestones/presentation/bloc/milestone_timeline_cubit.dart';
import 'features/settings/presentation/bloc/export_cubit.dart';
import 'features/settings/presentation/bloc/import_cubit.dart';
import 'features/settings/presentation/bloc/people_cubit.dart';

final sl = GetIt.instance;

// Web OAuth client ID — only needed on web (mobile reads from google-services.json).
/// Call once in main() after Supabase.initialize().
Future<void> init() async {
  // ─── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<PeopleFacesRevisionNotifier>(
      PeopleFacesRevisionNotifier.new);
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
        [
          MilestoneCollectionSchema,
          PersonCollectionSchema,
          GroupCollectionSchema,
          PersonGroupLinkCollectionSchema,
          RelationshipCollectionSchema,
          CategoryCollectionSchema,
          SavedLocationCollectionSchema,
          LocalUserSessionCollectionSchema,
          UserProfileCollectionSchema,
        ],
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
          [
            MilestoneCollectionSchema,
            RelationshipCollectionSchema,
            CategoryCollectionSchema,
            SavedLocationCollectionSchema,
            LocalUserSessionCollectionSchema,
            UserProfileCollectionSchema,
          ],
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
      sl.registerLazySingleton<IsarSavedLocationDataSource>(
        () => IsarSavedLocationDataSourceImpl(sl()),
      );
      if (peopleEnabled) {
        sl.registerLazySingleton<PersonGroupLocalDataSource>(
          () => PersonGroupLocalDataSourceImpl(sl<Isar>()),
        );
      } else {
        sl.registerLazySingleton<PersonGroupLocalDataSource>(
          () => _WebPersonGroupLocalDataSource(),
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
      sl.registerLazySingleton<IsarSavedLocationDataSource>(
        () => _WebSavedLocationDataSource(),
      );
      sl.registerLazySingleton<PersonGroupLocalDataSource>(
        () => _WebPersonGroupLocalDataSource(),
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
    sl.registerLazySingleton<IsarSavedLocationDataSource>(
      () => _WebSavedLocationDataSource(),
    );
    sl.registerLazySingleton<PersonGroupLocalDataSource>(
      () => _WebPersonGroupLocalDataSource(),
    );
  }

  sl.registerLazySingleton<IsarRelationshipDataSource>(() {
    if (sl.isRegistered<Isar>()) {
      return IsarRelationshipDataSourceImpl(sl());
    }
    return _WebRelationshipDataSource();
  });
  sl.registerLazySingleton<RelationshipService>(
    () => RelationshipService(sl<IsarRelationshipDataSource>()),
  );

  if (sl.isRegistered<Isar>()) {
    sl.registerLazySingleton<UserProfileLocalDataSource>(
      () => IsarUserProfileLocalDataSourceImpl(sl<Isar>()),
    );
  } else {
    sl.registerLazySingleton<UserProfileLocalDataSource>(
      () => NoOpUserProfileLocalDataSource(),
    );
  }

  // ─── Local seeds ──────────────────────────────────────────────────────────
  try {
    await sl<IsarCategoryDataSource>().ensureSeeded();
  } catch (_) {
    // Best-effort seed; app remains usable without it.
  }

  // ─── Services ─────────────────────────────────────────────────────────────
  final premiumService = PremiumService();
  await premiumService.init();
  sl.registerLazySingleton<PremiumService>(() => premiumService);
  sl.registerLazySingleton<SyncPendingService>(
    () => SyncPendingService(
      sl<IsarMilestoneDataSource>(),
      sl<IsarPersonDataSource>(),
      sl<IsarRelationshipDataSource>(),
    ),
  );
  sl.registerLazySingleton<StorageMetricsService>(
    () => StorageMetricsService(
      sl<GoogleSignIn>(),
      sl<SyncPendingService>(),
    ),
  );
  sl.registerLazySingleton<GoogleDriveReauthBridge>(
    GoogleDriveReauthBridge.new,
  );
  sl.registerLazySingleton<CloudSyncActivityNotifier>(
    CloudSyncActivityNotifier.new,
  );
  sl.registerLazySingleton<MilestoneDriveMediaDownloader>(
    () => MilestoneDriveMediaDownloader(sl<GoogleSignIn>()),
  );
  sl.registerLazySingleton<BitacoraDriveImportProbe>(
    () => BitacoraDriveImportProbe(
      sl<PremiumService>(),
      sl<GoogleSignIn>(),
      DriveMilestoneMediaRestore(
        sl<IsarMilestoneDataSource>(),
        sl<LocalMediaStore>(),
      ),
    ),
  );
  sl.registerLazySingleton<LocalUserSettingsService>(
    () => LocalUserSettingsService(),
  );
  sl.registerLazySingleton<AuthLocalPersistence>(
    () => AuthLocalPersistence(
      sl<LocalUserSettingsService>(),
      sl.isRegistered<Isar>() ? sl<Isar>() : null,
    ),
  );
  // Note: DriveApi is constructed per-sync with fresh auth headers.
  sl.registerLazySingleton<CloudSyncStatusStore>(() {
    final store = CloudSyncStatusStore();
    unawaited(store.hydrate());
    return store;
  });
  sl.registerLazySingleton<SyncStatusCubit>(SyncStatusCubit.new);
  sl.registerLazySingleton<CloudSyncService>(
    () => CloudSyncService(
      sl(),
      sl<GoogleSignIn>(),
      sl<IsarMilestoneDataSource>(),
      sl<IsarPersonDataSource>(),
      sl<GoogleDriveReauthBridge>(),
      sl<LocalMediaStore>(),
      sl<CloudSyncActivityNotifier>(),
      sl<SyncStatusCubit>(),
    ),
  );
  if (sl.isRegistered<Isar>()) {
    sl.registerLazySingleton<SyncService>(
      () => SyncService(
        sl<SupabaseClient>(),
        sl<Isar>(),
        sl<PremiumService>(),
        sl<ProfileRemoteDataSource>(),
        sl<CloudSyncService>(),
        sl<MilestoneRemoteDataSource>(),
        sl<IsarMilestoneDataSource>(),
        sl<IsarPersonDataSource>(),
        sl<IsarRelationshipDataSource>(),
        sl<PersonGroupLocalDataSource>(),
        sl<IsarCategoryDataSource>(),
        sl<IsarSavedLocationDataSource>(),
        sl<LocalMediaStore>(),
        sl<CloudSyncActivityNotifier>(),
        sl<CloudSyncStatusStore>(),
        sl<SyncStatusCubit>(),
      ),
    );
  }
  sl.registerLazySingleton<CleanupService>(
    () => CleanupService(sl<PremiumService>(), sl<IsarMilestoneDataSource>()),
  );
  sl.registerLazySingleton<SpaceCleanupService>(
    () => SpaceCleanupService(sl<PremiumService>(), sl<IsarMilestoneDataSource>()),
  );
  sl.registerLazySingleton<FaceCropperService>(
    () => FaceCropperServiceImpl(
      personDs: sl<IsarPersonDataSource>(),
      personGroupDs: sl<PersonGroupLocalDataSource>(),
    ),
  );
  sl.registerLazySingleton<MilestoneLocationResolver>(
    () => const MilestoneLocationResolver(),
  );

  // ─── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<MilestoneRemoteDataSource>(
    () => MilestoneRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthService>(
    () => AuthService(sl<SupabaseClient>(), sl<GoogleSignIn>()),
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
      sl<LocalMediaStore>(),
      sl<IsarPersonDataSource>(),
      sl<IsarCategoryDataSource>(),
      sl<IsarSavedLocationDataSource>(),
      sl<IsarRelationshipDataSource>(),
      sl<PersonGroupLocalDataSource>(),
    ),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthService>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      sl(),
      sl(),
      sl<IsarPersonDataSource>(),
      sl<UserProfileLocalDataSource>(),
      sl<PeopleFacesRevisionNotifier>(),
    ),
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
  sl.registerFactory<ExportBitacoraUseCase>(() => ExportBitacoraUseCase(
        sl(),
        sl<IsarPersonDataSource>(),
        sl<IsarCategoryDataSource>(),
        sl<IsarSavedLocationDataSource>(),
        sl<IsarRelationshipDataSource>(),
        sl<PersonGroupLocalDataSource>(),
      ));
  sl.registerFactory<ImportBitacoraUseCase>(() => ImportBitacoraUseCase(sl()));

  // ─── Cubits ───────────────────────────────────────────────────────────────
  sl.registerFactory<MilestoneTimelineCubit>(() => MilestoneTimelineCubit(sl()));
  sl.registerFactory<CreateMilestoneCubit>(
      () => CreateMilestoneCubit(sl(), sl()));
  sl.registerFactory<EditMilestoneCubit>(() => EditMilestoneCubit(sl()));
  sl.registerFactory<DeleteMilestoneCubit>(() => DeleteMilestoneCubit(sl()));
  sl.registerFactory<ExportCubit>(() => ExportCubit(sl()));
  sl.registerFactory<ImportCubit>(() => ImportCubit(sl()));
  sl.registerFactory<PeopleCubit>(
      () => PeopleCubit(
            sl<IsarPersonDataSource>(),
            sl<PersonGroupLocalDataSource>(),
            sl<IsarMilestoneDataSource>(),
            sl<IsarRelationshipDataSource>(),
            sl<PremiumService>(),
            sl<CloudSyncService>(),
            sl<FaceCropperService>(),
            sl<ProfileRemoteDataSource>(),
          ));
  sl.registerFactory<MapCubit>(() => MapCubit(sl()));
  sl.registerFactory<RelationshipTreeCubit>(
    () => RelationshipTreeCubit(
      sl<IsarRelationshipDataSource>(),
      sl<IsarPersonDataSource>(),
      sl<RelationshipService>(),
    ),
  );
  sl.registerFactory<GroupGraphCubit>(
    () => GroupGraphCubit(
      sl<PersonGroupLocalDataSource>(),
      sl<IsarPersonDataSource>(),
      sl<IsarMilestoneDataSource>(),
    ),
  );
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      sl<AuthRepository>(),
      sl<PremiumService>(),
      sl<ProfileRepository>(),
      sl<SupabaseClient>(),
      sl<AuthLocalPersistence>(),
      sl<UserProfileLocalDataSource>(),
      sl<GoogleDriveReauthBridge>(),
    ),
  );

  // ─── Local seeds ──────────────────────────────────────────────────────────
  // (No category seeding: categories are now fixed constants.)

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
    final sorted = [..._store.where((c) => !c.isDeleted)]
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return sorted;
  }

  @override
  Future<MilestoneCollection?> fetchById(String id) async {
    final item = _store.where((c) => c.id == id).firstOrNull;
    if (item == null || item.isDeleted) return null;
    return item;
  }

  @override
  Future<MilestoneCollection?> fetchCollectionById(String id) async =>
      _store.where((c) => c.id == id).firstOrNull;

  @override
  Future<MilestoneCollection> upsert(MilestoneCollection c) async {
    _store.removeWhere((e) => e.id == c.id);
    _store.add(c);
    return c;
  }

  @override
  Future<List<MilestoneCollection>> fetchDeleted() async =>
      _store.where((c) => c.isDeleted).toList();

  @override
  Future<void> hardDelete(MilestoneCollection item) async {
    _store.removeWhere((e) => e.id == item.id);
  }

  @override
  Future<void> deleteById(String id, {bool softDelete = false}) async {
    final item = _store.where((c) => c.id == id).firstOrNull;
    if (item == null) return;
    if (softDelete) {
      item
        ..isDeleted = true
        ..isSynced = false
        ..syncStatus = SyncStatus.pending;
      return;
    }
    await hardDelete(item);
  }

  @override
  Future<void> markSynced(String id) async {
    final item = _store.where((e) => e.id == id).firstOrNull;
    if (item != null) {
      item.syncStatus = SyncStatus.synced;
      item.isSynced = true;
      item.supabaseId ??= item.id;
    }
  }

  @override
  Future<List<MilestoneLocationDataEmbed>> fetchRecentLocations({
    int limit = 8,
  }) async {
    final seen = <String>{};
    final out = <MilestoneLocationDataEmbed>[];
    String keyOf(MilestoneLocationDataEmbed l) {
      final name = (l.name ?? '').trim().toLowerCase();
      final lat = l.latitude;
      final lon = l.longitude;
      final latKey = lat == null ? '' : lat.toStringAsFixed(5);
      final lonKey = lon == null ? '' : lon.toStringAsFixed(5);
      return '$name|$latKey|$lonKey';
    }

    final sorted = [..._store]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final m in sorted) {
      final loc = m.location ??
          (() {
            final name = m.locationName;
            final lat = m.latitude;
            final lon = m.longitude;
            if ((name == null || name.trim().isEmpty) &&
                lat == null &&
                lon == null) {
              return null;
            }
            return MilestoneLocationDataEmbed()
              ..name = name
              ..latitude = lat
              ..longitude = lon;
          })();
      if (loc == null) continue;
      final k = keyOf(loc);
      if (k.trim().isEmpty) continue;
      if (!seen.add(k)) continue;
      out.add(loc);
      if (out.length >= limit.clamp(1, 20)) break;
    }
    return out;
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
      _store
          .where((c) => !c.isDeleted && c.syncStatus == SyncStatus.pending)
          .toList();

  @override
  Future<List<MilestoneCollection>> fetchUnsynced() async =>
      _store.where((c) => !c.isDeleted && !c.isSynced).toList();

  @override
  Future<void> renameLocationForCoordinates({
    required double latitude,
    required double longitude,
    required String newName,
  }) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    final latKey = latitude.toStringAsFixed(5);
    final lonKey = longitude.toStringAsFixed(5);

    for (final m in _store) {
      final loc = m.location;
      final lat = loc?.latitude ?? m.latitude;
      final lon = loc?.longitude ?? m.longitude;
      if (lat == null || lon == null) continue;
      if (lat.toStringAsFixed(5) != latKey) continue;
      if (lon.toStringAsFixed(5) != lonKey) continue;

      final currentName = (loc?.name ?? m.locationName ?? '').trim();
      if (currentName.isEmpty) continue;
      if (currentName == name) continue;

      (m.location ??= MilestoneLocationDataEmbed())
        ..name = name
        ..latitude = lat
        ..longitude = lon;
      m.locationName = name;
    }
  }

  @override
  Future<void> syncSavedLocationToMilestones({
    required int savedLocationId,
    required String name,
    required String? city,
    required String? country,
    required double? latitude,
    required double? longitude,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return;
    for (final m in _store) {
      if (m.savedLocationId != savedLocationId) continue;
      (m.location ??= MilestoneLocationDataEmbed())
        ..name = n
        ..city = (city ?? '').trim().isEmpty ? null : city!.trim()
        ..country = (country ?? '').trim().isEmpty ? null : country!.trim()
        ..latitude = latitude
        ..longitude = longitude;
      m.locationName = n;
      m.latitude = latitude;
      m.longitude = longitude;
    }
  }

  @override
  Future<void> removePersonFromAllMilestones(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    for (final m in _store) {
      if (!m.participants.contains(pid) && !m.protagonists.contains(pid)) {
        continue;
      }
      m.participants = m.participants.where((id) => id != pid).toList();
      m.protagonists = m.protagonists.where((id) => id != pid).toList();
    }
  }

  @override
  Future<int> countMilestonesContainingPerson(String personId) async {
    final pid = personId.trim();
    if (pid.isEmpty) return 0;
    var n = 0;
    for (final m in _store) {
      if (m.participants.contains(pid) || m.protagonists.contains(pid)) {
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> countMilestonesUsingSavedLocation(int savedLocationId) async {
    if (savedLocationId <= 0) return 0;
    var n = 0;
    for (final m in _store) {
      if (m.isDeleted) continue;
      if (m.savedLocationId == savedLocationId) n++;
    }
    return n;
  }

  @override
  Future<int> countUnsyncedMediaItems() async {
    var n = 0;
    for (final m in _store) {
      if (m.isDeleted) continue;
      for (final item in m.mediaItems) {
        if (!item.isDeleted && !item.isSynced) n++;
      }
    }
    return n;
  }

  @override
  Future<int> countUnsyncedMilestones() async {
    var n = 0;
    for (final m in _store) {
      if (!m.isDeleted && !m.isSynced) n++;
    }
    return n;
  }
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
  Future<PersonCollection?> fetchById(String id) async {
    final item = await fetchByIdIncludingDeleted(id);
    if (item == null || item.isDeleted) return null;
    return item;
  }

  @override
  Future<PersonCollection?> fetchByIdIncludingDeleted(String id) async =>
      _store.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<PersonCollection>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final wanted = ids.toSet();
    return _store.where((p) => wanted.contains(p.id)).toList();
  }

  @override
  Future<PersonCollection?> fetchByLinkedUserId(String linkedUserId) async {
    final v = linkedUserId.trim();
    if (v.isEmpty) return null;
    return _store
        .where((p) => (p.linkedUserId ?? '').trim() == v)
        .firstOrNull;
  }

  @override
  Future<List<PersonCollection>> fetchAll() async =>
      List.unmodifiable(_store.where((p) => !p.isDeleted));

  @override
  Future<List<PersonCollection>> fetchDeleted() async =>
      _store.where((p) => p.isDeleted).toList();

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
  Future<void> hardDelete(PersonCollection item) async {
    _store.removeWhere((e) => e.id == item.id);
  }

  @override
  Future<void> deleteById(String id, {bool softDelete = false}) async {
    final item = _store.where((e) => e.id == id).firstOrNull;
    if (item == null) return;
    if (softDelete) {
      item
        ..isDeleted = true
        ..isSynced = false;
      return;
    }
    await hardDelete(item);
  }

  @override
  Future<int> countUnsynced() async {
    var n = 0;
    for (final p in _store) {
      if (!p.isDeleted && !p.isSynced) n++;
    }
    return n;
  }
}

class _WebPersonGroupLocalDataSource implements PersonGroupLocalDataSource {
  @override
  Future<void> ensureSeededAndMigrateLegacy(
    IsarPersonDataSource personDs,
  ) async {}

  @override
  Future<List<PersonGroupLinkCollection>> fetchAllLinks() async => const [];

  @override
  Future<List<GroupCollection>> fetchAllGroupsOrdered() async => const [];

  @override
  Future<String> createCustomGroup(String name) async {
    throw UnsupportedError('Grupos no disponibles en este modo.');
  }

  @override
  Future<void> replacePersonMemberships(
    String personId,
    List<String> groupIds,
  ) async {}

  @override
  Future<List<String>> groupIdsForPerson(String personId) async => const [];

  @override
  Future<Map<String, List<String>>> buildPersonIdToGroupIds() async =>
      const {};

  @override
  Future<void> removeAllMembershipsForPerson(String personId) async {}

  @override
  Future<void> upsertGroup(GroupCollection row) async {}

  @override
  Future<void> putPersonGroupLinkForImport(
    String personId,
    String groupId,
  ) async {}
}

class _WebCategoryDataSource implements IsarCategoryDataSource {
  final List<CategoryCollection> _store = [];

  CategoryCollection _fromSeed(MilestoneCategorySeed s) =>
      CategoryCollection()
        ..id = s.id
        ..name = s.name
        ..iconName = s.iconKey
        ..colorValue = s.colorArgb;

  @override
  Future<void> ensureSeeded() async {
    if (_store.isEmpty) {
      _store.addAll(kMilestoneCategorySeeds.map(_fromSeed));
      return;
    }
    final have = _store.map((e) => e.id.toLowerCase()).toSet();
    for (final s in kMilestoneCategorySeeds) {
      if (have.contains(s.id.toLowerCase())) continue;
      _store.add(_fromSeed(s));
      have.add(s.id.toLowerCase());
    }
  }

  @override
  Future<List<CategoryCollection>> fetchAll() async {
    await ensureSeeded();
    final sorted = [..._store]..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<CategoryCollection?> fetchByCategoryId(String id) async {
    await ensureSeeded();
    final v = id.trim().toLowerCase();
    return _store.where((c) => c.id.toLowerCase() == v).firstOrNull;
  }

  @override
  Future<CategoryCollection> upsert(CategoryCollection c) async {
    await ensureSeeded();
    final existing = await fetchByCategoryId(c.id);
    if (existing != null) _store.remove(existing);
    _store.add(c);
    return c;
  }

  @override
  Future<void> deleteByCategoryId(String id) async {
    await ensureSeeded();
    final existing = await fetchByCategoryId(id);
    if (existing != null) _store.remove(existing);
  }
}

class _WebRelationshipDataSource implements IsarRelationshipDataSource {
  final List<RelationshipCollection> _store = [];

  @override
  Future<RelationshipCollection?> fetchById(String id) async {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final r in _store) {
      if (r.id == needle && !r.isDeleted) return r;
    }
    return null;
  }

  @override
  Future<List<RelationshipCollection>> fetchAll() async =>
      List.unmodifiable(_store.where((r) => !r.isDeleted));

  @override
  Future<List<RelationshipCollection>> fetchDeleted() async =>
      _store.where((r) => r.isDeleted).toList();

  @override
  Future<List<RelationshipCollection>> findInvolvingPerson(
    String personId,
  ) async {
    final pid = personId.trim().toLowerCase();
    if (pid.isEmpty) return const [];
    return _store
        .where(
          (r) =>
              r.personId.toLowerCase() == pid ||
              r.relatedPersonId.toLowerCase() == pid,
        )
        .toList();
  }

  @override
  Future<void> put(RelationshipCollection row) async {
    final i = _store.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      _store[i] = row;
    } else {
      _store.add(row);
    }
  }

  @override
  Future<void> hardDelete(RelationshipCollection item) async {
    _store.removeWhere((e) => e.id == item.id);
  }

  @override
  Future<void> deleteById(String id, {bool softDelete = false}) async {
    final item = _store.where((e) => e.id == id).firstOrNull;
    if (item == null) return;
    if (softDelete) {
      item
        ..isDeleted = true
        ..isSynced = false;
      return;
    }
    await hardDelete(item);
  }

  @override
  Future<void> deleteAllInvolvingPerson(
    String personId, {
    bool softDelete = false,
  }) async {
    final pid = personId.trim();
    if (pid.isEmpty) return;
    if (softDelete) {
      for (final r in _store) {
        if (r.personId != pid && r.relatedPersonId != pid) continue;
        r
          ..isDeleted = true
          ..isSynced = false;
      }
      return;
    }
    _store.removeWhere(
      (r) => r.personId == pid || r.relatedPersonId == pid,
    );
  }

  @override
  Future<int> countUnsynced() async {
    var n = 0;
    for (final r in _store) {
      if (!r.isDeleted && !r.isSynced) n++;
    }
    return n;
  }
}

class _WebSavedLocationDataSource implements IsarSavedLocationDataSource {
  final List<SavedLocationCollection> _store = [];
  int _nextId = 1;

  @override
  Future<List<SavedLocationCollection>> fetchAll() async {
    final sorted = [..._store]..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<SavedLocationCollection?> fetchById(Id isarId) async =>
      _store.where((e) => e.isarId == isarId).firstOrNull;

  @override
  Future<SavedLocationCollection> upsert(SavedLocationCollection c) async {
    if (c.isarId != Isar.autoIncrement) {
      final existing = _store.where((e) => e.isarId == c.isarId).firstOrNull;
      if (existing != null && c.clientId.trim().isEmpty) {
        c.clientId = existing.clientId;
      }
      _store.removeWhere((e) => e.isarId == c.isarId);
    }
    if (c.clientId.trim().isEmpty) {
      c.clientId = 'web-${DateTime.now().microsecondsSinceEpoch}';
    }
    if (c.isarId == Isar.autoIncrement) {
      c.isarId = _nextId++;
    } else {
      _nextId = (_nextId <= c.isarId) ? (c.isarId + 1) : _nextId;
    }
    _store.add(c);
    return c;
  }

  @override
  Future<void> deleteById(Id isarId) async =>
      _store.removeWhere((e) => e.isarId == isarId);
}

// (Local user settings are stored via SharedPreferences, not Isar.)
