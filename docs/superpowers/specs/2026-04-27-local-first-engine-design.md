# Local-First Engine — Task 26

**Date:** 2026-04-27  
**Status:** Approved  
**Approach:** Write-Through Hybrid Repository (Option A)

---

## Overview

LifeTime requires login (Google) but by default stores all data locally in Isar. Cloud sync (Supabase + Drive + Biographer AI) only activates when the user enables **Premium mode** via a Settings toggle. This preserves data sovereignty: photos and milestones live on the device first.

---

## 1. Dependencies

### `pubspec.yaml` additions

```yaml
dependencies:
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0      # native binary per platform
  path_provider: ^2.1.0           # documents dir for Isar
  uuid: ^4.3.0                    # generate local UUIDs for offline/free milestones
  shared_preferences: ^2.2.0      # persist isPremium between sessions

dev_dependencies:
  isar_generator: ^3.1.0          # generates *.g.dart for collections
  build_runner: ^2.4.0
```

---

## 2. Isar Schemas

Location: `lib/features/milestones/data/models/local/`

### `milestone_collection.dart`

```dart
part 'milestone_collection.g.dart';

enum SyncStatus { synced, pending }

@Collection()
class MilestoneCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;          // UUID (Supabase ID when synced, local UUID when pending)

  late String userId;
  late String title;
  String? description;
  late List<String> participants;
  late DateTime eventDate;
  String? locationName;
  double? latitude;
  double? longitude;
  late String category;
  late bool isPublic;
  late DateTime createdAt;
  String? driveFileId;

  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  late List<MediaAssetEmbed> media;  // embedded, not IsarLinks
}
```

### `media_asset_embed.dart`

```dart
part 'media_asset_embed.g.dart';

@Embedded()
class MediaAssetEmbed {
  late String id;
  late String milestoneId;
  late String cloudFileId;
  String? thumbnailUrl;
  late String mediaType;
  late DateTime createdAt;
  String? metadataJson;   // serialized Map<String, dynamic>
}
```

Embedded (not `IsarLinks`) keeps each milestone self-contained. No lazy-load complexity.

---

## 3. `IsarMilestoneDataSource`

Location: `lib/data/datasources/isar_milestone_datasource.dart`

### Interface

```dart
abstract class IsarMilestoneDataSource {
  Future<List<MilestoneCollection>> fetchAll();
  Future<MilestoneCollection?> fetchById(String id);
  Future<MilestoneCollection> upsert(MilestoneCollection c);
  Future<void> deleteById(String id);
  Future<void> markSynced(String id);
  Future<List<MilestoneCollection>> fetchPending();
}
```

### Implementation (`IsarMilestoneDataSourceImpl`)

- Constructor: `IsarMilestoneDataSourceImpl(Isar isar)`
- `fetchAll()` — `isar.milestoneCollections.where().findAll()` sorted by `eventDate` desc
- `upsert()` — `isar.writeTxn(() => isar.milestoneCollections.put(c))`; returns the saved collection
- `deleteById(id)` — query by UUID string index, then delete by `isarId`
- `markSynced(id)` — fetch → set `syncStatus = SyncStatus.synced` → put
- `fetchPending()` — `.filter().syncStatusEqualTo(SyncStatus.pending).findAll()`

### DI Initialization (in `di.init()`, before datasources)

```dart
final dir = await getApplicationDocumentsDirectory();
final isar = await Isar.open(
  [MilestoneCollectionSchema],
  directory: dir.path,
);
sl.registerSingleton<Isar>(isar);
sl.registerLazySingleton<IsarMilestoneDataSource>(
  () => IsarMilestoneDataSourceImpl(sl()),
);
```

---

## 4. `PremiumService`

Location: `lib/core/services/premium_service.dart`

Singleton shared between data layer and presentation layer. Prevents `MilestoneRepositoryImpl` from depending on `AuthCubit`.

```dart
class PremiumService {
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
  }
}
```

DI: `sl.registerLazySingleton<PremiumService>(() => PremiumService())`

Dependency: add `shared_preferences: ^2.2.0` to `pubspec.yaml`.

---

## 5. Hybrid `MilestoneRepositoryImpl`

Constructor: `(IsarMilestoneDataSource local, MilestoneRemoteDataSource remote, PremiumService premium)`

### Behavior Matrix

| Operation | Free user | Premium (online) | Premium (offline) |
|---|---|---|---|
| `getMilestones` | Read Isar only | If Isar empty → seed from Supabase → return Isar | Read Isar |
| `createMilestone` | Title = *"Hito del {date}"*, desc = userNote → Isar `pending` | Biographer → remote insert → Isar `synced` | Biographer or insert fails → Isar `pending` |
| `deleteMilestone` | Delete from Isar | Delete from Isar + remote (best-effort) | Delete from Isar |
| `updateMilestone` | Update Isar → `pending` | Update Isar + remote → `synced` | Update Isar → `pending` |

### Key Rule

Network failures on write **never return `Left`**. The milestone is saved locally with `syncStatus = pending` and a `Right` is returned. Only a local Isar write failure produces `Left`.

### `getMilestones()` Flow

```
1. local.fetchAll()
2. if list is non-empty → map to domain entities → return Right(list)
3. if list is empty AND premium.isPremium:
     models = remote.fetchMilestones()
     for each model: local.upsert(model.toCollection(syncStatus: synced))
     return Right(mapped entities)
4. if list is empty AND free → return Right([])
```

### `createMilestone()` Flow

```
if premium.isPremium:
  try:
    biographerResult = remote.callBiographerNarrative(...)
    remoteModel = remote.insertMilestone(insertMap)
    local.upsert(remoteModel.toCollection(syncStatus: synced))
    return Right(remoteModel)
  catch any network/auth error:
    // biographer OR insert failed — save locally with fallback title
    title = biographerResult?.title ?? 'Hito del ${_formatDate(eventDate)}'
    description = biographerResult?.narrative ?? userNote
    localCollection = _buildLocal(title, description, params, syncStatus: pending)
    local.upsert(localCollection)
    return Right(localCollection.toDomain())
else:
  localCollection = _buildLocal(
    title: 'Hito del ${_formatDate(eventDate)}',
    description: userNote,
    params,
    syncStatus: pending,
  )
  local.upsert(localCollection)
  return Right(localCollection.toDomain())
```

`_buildLocal` generates a UUID with the `uuid` package for the `id` field.

---

## 6. `AuthCubit` Changes

### `AuthAuthenticated` state

```dart
class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final bool isPremium;    // new field, default false
  const AuthAuthenticated(this.user, {this.isPremium = false});
  @override List<Object?> get props => [user, isPremium];
}
```

### `AuthCubit`

New constructor parameter: `PremiumService _premiumService`.

```dart
Future<void> checkCurrentUser() async {
  await _premiumService.init();
  final user = await _authRepository.getCurrentUser();
  if (user != null) emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
  else emit(const AuthUnauthenticated());
}

Future<void> setPremium(bool value) async {
  await _premiumService.setPremium(value);
  final s = state;
  if (s is AuthAuthenticated) emit(AuthAuthenticated(s.user, isPremium: value));
}
```

DI: `sl.registerFactory<AuthCubit>(() => AuthCubit(sl(), sl()))`.

---

## 7. `SettingsPage` Changes

Add a new section above Sign Out:

```dart
BlocBuilder<AuthCubit, AuthState>(
  builder: (ctx, state) {
    final isPremium = state is AuthAuthenticated && state.isPremium;
    return SwitchListTile(
      title: const Text('Sincronización en la Nube'),
      subtitle: const Text('Premium · Biographer IA + Google Drive'),
      value: isPremium,
      onChanged: (v) => ctx.read<AuthCubit>().setPremium(v),
    );
  },
),
const Divider(),
```

When OFF: zero calls to Supabase functions, Drive, or Biographer AI.

---

## 8. TDD Strategy

### New: `test/data/datasources/isar_milestone_datasource_test.dart`

Uses a real Isar instance opened on `Directory.systemTemp.path` in `setUp`, closed and deleted in `tearDown`. Covers:

- `upsert` → `fetchAll` returns the collection
- `fetchById` returns correct item by UUID
- `deleteById` removes from store
- `markSynced` updates `syncStatus` without changing other fields
- `fetchPending` returns only `pending` items

### Updated: `test/data/repositories/milestone_repository_impl_test.dart`

```dart
mockLocal = MockIsarMilestoneDataSource()
mockRemote = MockMilestoneRemoteDataSource()
mockPremium = MockPremiumService()
```

Critical new cases:

| Test | Assertion |
|---|---|
| Free user: `createMilestone` | `callBiographerNarrative` never called; `insertMilestone` never called |
| Free user: `getMilestones` | `fetchMilestones` never called; reads `mockLocal.fetchAll()` |
| Premium + empty Isar: `getMilestones` | calls `fetchMilestones`; calls `local.upsert` for each model |
| Premium + network fail on create | returns `Right`; `local.upsert` called with `syncStatus = pending` |
| Premium + online create | returns `Right`; `local.upsert` called with `syncStatus = synced` |

---

## 9. Out of Scope (this sprint)

- Automatic background sync of `pending` items when coming online
- Supabase `profiles` table for server-side premium gating
- Uploading locally-created milestones to Supabase after premium upgrade
- `getMilestones` remote-fallback when Isar is non-empty (always Isar-first once seeded)
