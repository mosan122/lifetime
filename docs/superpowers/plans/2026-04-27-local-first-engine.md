# Local-First Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make LifeTime work offline-first using Isar as local DB, syncing to Supabase only when the user has Premium mode enabled.

**Architecture:** `MilestoneRepositoryImpl` receives two datasources (`IsarMilestoneDataSource` + `MilestoneRemoteDataSource`) and a `PremiumService`. Reads always come from Isar (seeded from Supabase on first run if premium+empty). Writes go to Isar first; remote is attempted only when `PremiumService.isPremium == true`.

**Tech Stack:** Isar 3.1.x (local DB + code gen), `uuid ^4.3.0` (local IDs), `shared_preferences ^2.2.0` (premium flag persistence), `path_provider ^2.1.0` (Isar directory).

---

## File Map

### New files
| Path | Responsibility |
|---|---|
| `lib/features/milestones/data/models/local/media_asset_embed.dart` | Isar `@Embedded()` for media assets |
| `lib/features/milestones/data/models/local/milestone_collection.dart` | Isar `@Collection()` for milestones + `SyncStatus` enum |
| `lib/features/milestones/data/models/local/milestone_collection.g.dart` | Generated — do not edit |
| `lib/features/milestones/data/models/local/media_asset_embed.g.dart` | Generated — do not edit |
| `lib/data/datasources/isar_milestone_datasource.dart` | Local CRUD interface + impl |
| `lib/core/services/premium_service.dart` | `isPremium` state + SharedPreferences persistence |
| `test/data/datasources/isar_milestone_datasource_test.dart` | TDD for Isar datasource |

### Modified files
| Path | Change |
|---|---|
| `pubspec.yaml` | +5 deps, +2 dev_deps |
| `lib/data/repositories/milestone_repository_impl.dart` | Hybrid write-through logic |
| `lib/injection_container.dart` | Wire Isar, PremiumService, updated constructors |
| `lib/features/auth/presentation/bloc/auth_state.dart` | `AuthAuthenticated` gains `isPremium` |
| `lib/features/auth/presentation/bloc/auth_cubit.dart` | Inject `PremiumService`, add `setPremium()` |
| `lib/features/settings/presentation/pages/settings_page.dart` | Add Premium `SwitchListTile` |
| `test/data/repositories/milestone_repository_impl_test.dart` | Rewrite for hybrid mocks |
| `test/features/auth/presentation/bloc/auth_cubit_test.dart` | Update for new constructor + `isPremium` |

---

## Task 1: Add dependencies to pubspec.yaml

**Files:** Modify `pubspec.yaml`

- [ ] **Open `pubspec.yaml` and replace the dependencies block with:**

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  dartz: ^0.10.1
  equatable: ^2.0.5
  get_it: ^8.0.0
  http: ^1.2.0
  flutter_bloc: ^8.1.6
  google_fonts: ^6.1.0
  google_sign_in: ^6.2.2
  googleapis: ^13.0.0
  image_picker: ^1.0.7
  cached_network_image: ^3.3.1
  image: ^4.0.0
  geolocator: ^12.0.0
  geocoding: ^3.0.0
  google_maps_flutter: ^2.5.0
  share_plus: ^10.0.0
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  path_provider: ^2.1.0
  uuid: ^4.3.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^0.3.0
  bloc_test: ^9.1.7
  flutter_lints: ^3.0.0
  isar_generator: ^3.1.0
  build_runner: ^2.4.0
```

- [ ] **Run pub get:**

```bash
powershell.exe -Command "flutter pub get"
```

Expected: `Resolving dependencies... Got dependencies!` with no errors.

- [ ] **Commit:**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add isar, uuid, shared_preferences, build_runner"
```

---

## Task 2: Create `MediaAssetEmbed` (Isar embedded object)

**Files:** Create `lib/features/milestones/data/models/local/media_asset_embed.dart`

- [ ] **Create the directory and file:**

```dart
// lib/features/milestones/data/models/local/media_asset_embed.dart
import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../../domain/entities/media_asset_entity.dart';

part 'media_asset_embed.g.dart';

@Embedded()
class MediaAssetEmbed {
  String id = '';
  String milestoneId = '';
  String cloudFileId = '';
  String? thumbnailUrl;
  String mediaType = '';
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? metadataJson;

  static MediaAssetEmbed fromEntity(MediaAssetEntity entity) {
    return MediaAssetEmbed()
      ..id = entity.id
      ..milestoneId = entity.milestoneId
      ..cloudFileId = entity.cloudFileId
      ..thumbnailUrl = entity.thumbnailUrl
      ..mediaType = entity.mediaType
      ..createdAt = entity.createdAt
      ..metadataJson =
          entity.metadata != null ? jsonEncode(entity.metadata) : null;
  }

  MediaAssetEntity toDomain() {
    return MediaAssetEntity(
      id: id,
      milestoneId: milestoneId,
      cloudFileId: cloudFileId,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      metadata:
          metadataJson != null ? jsonDecode(metadataJson!) as Map<String, dynamic> : null,
      createdAt: createdAt,
    );
  }
}
```

> Note: `@Embedded()` classes must have a no-arg constructor with default values for all fields — no `late` or `required`. Isar instantiates embedded objects via the default constructor.

---

## Task 3: Create `MilestoneCollection` (Isar collection)

**Files:** Create `lib/features/milestones/data/models/local/milestone_collection.dart`

- [ ] **Create the file:**

```dart
// lib/features/milestones/data/models/local/milestone_collection.dart
import 'package:isar/isar.dart';
import '../../../../domain/entities/milestone.dart';
import 'media_asset_embed.dart';

part 'milestone_collection.g.dart';

enum SyncStatus { synced, pending }

@Collection()
class MilestoneCollection {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String userId;
  late String title;
  String? description;
  List<String> participants = [];
  DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(0);
  String? locationName;
  double? latitude;
  double? longitude;
  late String category;
  late bool isPublic;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? driveFileId;

  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  List<MediaAssetEmbed> media = [];

  static MilestoneCollection fromMilestone(
      Milestone milestone, SyncStatus status) {
    return MilestoneCollection()
      ..id = milestone.id
      ..userId = milestone.userId
      ..title = milestone.title
      ..description = milestone.description
      ..participants = List<String>.from(milestone.participants)
      ..eventDate = milestone.eventDate
      ..locationName = milestone.locationName
      ..latitude = milestone.latitude
      ..longitude = milestone.longitude
      ..category = milestone.category
      ..isPublic = milestone.isPublic
      ..createdAt = milestone.createdAt
      ..driveFileId = milestone.driveFileId
      ..syncStatus = status
      ..media = milestone.media.map(MediaAssetEmbed.fromEntity).toList();
  }

  Milestone toDomain() {
    return Milestone(
      id: id,
      userId: userId,
      title: title,
      description: description,
      participants: List<String>.from(participants),
      media: media.map((e) => e.toDomain()).toList(),
      eventDate: eventDate,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      category: category,
      isPublic: isPublic,
      createdAt: createdAt,
      driveFileId: driveFileId,
    );
  }
}
```

> `@Collection()` classes CAN use `late` for fields Isar always sets via code-gen. `Id isarId` is Isar's internal int primary key; `String id` (with `@Index(unique: true)`) is our UUID.

---

## Task 4: Run code generation

**Files:** Generates `*.g.dart` files

- [ ] **Run build_runner:**

```bash
powershell.exe -Command "flutter pub run build_runner build --delete-conflicting-outputs"
```

Expected output contains:
```
[INFO] Generated: lib/features/milestones/data/models/local/media_asset_embed.g.dart
[INFO] Generated: lib/features/milestones/data/models/local/milestone_collection.g.dart
[INFO] Succeeded after ...
```

- [ ] **Verify the generated files exist:**

```bash
ls "lib/features/milestones/data/models/local/"
```

Expected: `media_asset_embed.dart`, `media_asset_embed.g.dart`, `milestone_collection.dart`, `milestone_collection.g.dart`

- [ ] **Commit:**

```bash
git add lib/features/milestones/data/models/local/
git commit -m "feat(local): add Isar schemas MilestoneCollection + MediaAssetEmbed"
```

---

## Task 5: Create `IsarMilestoneDataSource` (TDD)

**Files:**
- Create: `test/data/datasources/isar_milestone_datasource_test.dart`
- Create: `lib/data/datasources/isar_milestone_datasource.dart`

- [ ] **Write the failing test file:**

```dart
// test/data/datasources/isar_milestone_datasource_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

void main() {
  late Isar isar;
  late Directory tempDir;
  late IsarMilestoneDataSourceImpl datasource;

  MilestoneCollection _makeCollection({
    String id = 'ms-1',
    String title = 'Test Hito',
    SyncStatus syncStatus = SyncStatus.pending,
  }) {
    return MilestoneCollection()
      ..id = id
      ..userId = 'user-1'
      ..title = title
      ..description = 'Descripción de prueba'
      ..participants = ['Ana']
      ..eventDate = DateTime(2026, 4, 26)
      ..locationName = 'Madrid'
      ..latitude = 40.4168
      ..longitude = -3.7038
      ..category = 'general'
      ..isPublic = false
      ..createdAt = DateTime(2026, 4, 26, 10)
      ..syncStatus = syncStatus
      ..media = [];
  }

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('isar_test_${DateTime.now().microsecondsSinceEpoch}');
    isar = await Isar.open(
      [MilestoneCollectionSchema],
      directory: tempDir.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = IsarMilestoneDataSourceImpl(isar);
  });

  tearDown(() async {
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  group('upsert + fetchAll', () {
    test('upsert returns the collection and fetchAll contains it', () async {
      final collection = _makeCollection();

      await datasource.upsert(collection);
      final all = await datasource.fetchAll();

      expect(all, hasLength(1));
      expect(all.first.id, equals('ms-1'));
      expect(all.first.title, equals('Test Hito'));
    });

    test('fetchAll returns items ordered by eventDate descending', () async {
      await datasource.upsert(_makeCollection(
          id: 'ms-older', title: 'Older')
        ..eventDate = DateTime(2025, 1, 1));
      await datasource.upsert(_makeCollection(
          id: 'ms-newer', title: 'Newer')
        ..eventDate = DateTime(2026, 6, 1));

      final all = await datasource.fetchAll();

      expect(all.first.id, equals('ms-newer'));
      expect(all.last.id, equals('ms-older'));
    });

    test('upserting the same id updates in place', () async {
      final original = _makeCollection(title: 'Original');
      await datasource.upsert(original);

      final updated = _makeCollection(title: 'Updated');
      await datasource.upsert(updated);

      final all = await datasource.fetchAll();
      expect(all, hasLength(1));
      expect(all.first.title, equals('Updated'));
    });
  });

  group('fetchById', () {
    test('returns collection when id matches', () async {
      await datasource.upsert(_makeCollection(id: 'ms-abc'));

      final result = await datasource.fetchById('ms-abc');

      expect(result, isNotNull);
      expect(result!.id, equals('ms-abc'));
    });

    test('returns null when id not found', () async {
      final result = await datasource.fetchById('nonexistent');
      expect(result, isNull);
    });
  });

  group('deleteById', () {
    test('removes the item from the store', () async {
      await datasource.upsert(_makeCollection());

      await datasource.deleteById('ms-1');

      final all = await datasource.fetchAll();
      expect(all, isEmpty);
    });

    test('is idempotent when id does not exist', () async {
      await expectLater(
        datasource.deleteById('nonexistent'),
        completes,
      );
    });
  });

  group('markSynced', () {
    test('updates syncStatus to synced without changing other fields', () async {
      await datasource.upsert(_makeCollection(syncStatus: SyncStatus.pending));

      await datasource.markSynced('ms-1');

      final item = await datasource.fetchById('ms-1');
      expect(item, isNotNull);
      expect(item!.syncStatus, equals(SyncStatus.synced));
      expect(item.title, equals('Test Hito'));
    });

    test('is idempotent when id does not exist', () async {
      await expectLater(datasource.markSynced('nonexistent'), completes);
    });
  });

  group('fetchPending', () {
    test('returns only pending items', () async {
      await datasource.upsert(_makeCollection(
          id: 'ms-synced', syncStatus: SyncStatus.synced));
      await datasource.upsert(_makeCollection(
          id: 'ms-pending', syncStatus: SyncStatus.pending));

      final pending = await datasource.fetchPending();

      expect(pending, hasLength(1));
      expect(pending.first.id, equals('ms-pending'));
    });

    test('returns empty list when no pending items', () async {
      await datasource.upsert(_makeCollection(syncStatus: SyncStatus.synced));

      final pending = await datasource.fetchPending();

      expect(pending, isEmpty);
    });
  });
}
```

- [ ] **Run the test to confirm it fails (file not found):**

```bash
powershell.exe -Command "flutter test test/data/datasources/isar_milestone_datasource_test.dart -v 2>&1 | Select-String -Pattern 'FAIL|Error|error' | Select-Object -First 5"
```

Expected: compile error because `IsarMilestoneDataSourceImpl` doesn't exist yet.

- [ ] **Create the implementation:**

```dart
// lib/data/datasources/isar_milestone_datasource.dart
import 'package:isar/isar.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

abstract class IsarMilestoneDataSource {
  Future<List<MilestoneCollection>> fetchAll();
  Future<MilestoneCollection?> fetchById(String id);
  Future<MilestoneCollection> upsert(MilestoneCollection c);
  Future<void> deleteById(String id);
  Future<void> markSynced(String id);
  Future<List<MilestoneCollection>> fetchPending();
}

class IsarMilestoneDataSourceImpl implements IsarMilestoneDataSource {
  final Isar _isar;
  IsarMilestoneDataSourceImpl(this._isar);

  @override
  Future<List<MilestoneCollection>> fetchAll() =>
      _isar.milestoneCollections
          .where()
          .sortByEventDateDesc()
          .findAll();

  @override
  Future<MilestoneCollection?> fetchById(String id) =>
      _isar.milestoneCollections
          .filter()
          .idEqualTo(id)
          .findFirst();

  @override
  Future<MilestoneCollection> upsert(MilestoneCollection c) async {
    await _isar.writeTxn(() => _isar.milestoneCollections.put(c));
    return c;
  }

  @override
  Future<void> deleteById(String id) async {
    final item = await fetchById(id);
    if (item == null) return;
    await _isar.writeTxn(
      () => _isar.milestoneCollections.delete(item.isarId),
    );
  }

  @override
  Future<void> markSynced(String id) async {
    final item = await fetchById(id);
    if (item == null) return;
    item.syncStatus = SyncStatus.synced;
    await _isar.writeTxn(() => _isar.milestoneCollections.put(item));
  }

  @override
  Future<List<MilestoneCollection>> fetchPending() =>
      _isar.milestoneCollections
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .findAll();
}
```

> The import path `'../features/milestones/data/models/local/milestone_collection.dart'` is relative from `lib/data/datasources/`. Adjust if needed.

- [ ] **Run the tests to confirm they pass:**

```bash
powershell.exe -Command "flutter test test/data/datasources/isar_milestone_datasource_test.dart -v"
```

Expected: `All tests passed!` (10 tests)

- [ ] **Commit:**

```bash
git add lib/data/datasources/isar_milestone_datasource.dart test/data/datasources/isar_milestone_datasource_test.dart
git commit -m "feat(local): add IsarMilestoneDataSource with CRUD + TDD"
```

---

## Task 6: Create `PremiumService` (TDD)

**Files:**
- Create: `test/core/services/premium_service_test.dart`
- Create: `lib/core/services/premium_service.dart`

- [ ] **Write the failing test:**

```dart
// test/core/services/premium_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifetime/core/services/premium_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('isPremium is false before init()', () {
    final service = PremiumService();
    expect(service.isPremium, isFalse);
  });

  test('init() loads false when no preference is stored', () async {
    final service = PremiumService();
    await service.init();
    expect(service.isPremium, isFalse);
  });

  test('init() loads true when preference was previously set to true', () async {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    final service = PremiumService();
    await service.init();
    expect(service.isPremium, isTrue);
  });

  test('setPremium(true) updates getter immediately', () async {
    final service = PremiumService();
    await service.init();
    await service.setPremium(true);
    expect(service.isPremium, isTrue);
  });

  test('setPremium(false) reverts the getter', () async {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    final service = PremiumService();
    await service.init();
    await service.setPremium(false);
    expect(service.isPremium, isFalse);
  });

  test('setPremium persists across instances', () async {
    final serviceA = PremiumService();
    await serviceA.init();
    await serviceA.setPremium(true);

    final serviceB = PremiumService();
    await serviceB.init();
    expect(serviceB.isPremium, isTrue);
  });
}
```

- [ ] **Run to confirm it fails:**

```bash
powershell.exe -Command "flutter test test/core/services/premium_service_test.dart -v 2>&1 | Select-String -Pattern 'FAIL|Error' | Select-Object -First 5"
```

Expected: compile error (class not defined).

- [ ] **Create the implementation:**

```dart
// lib/core/services/premium_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  static const _key = 'is_premium';
  bool _isPremium = false;

  bool get isPremium => _isPremium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_key) ?? false;
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
```

- [ ] **Run the tests:**

```bash
powershell.exe -Command "flutter test test/core/services/premium_service_test.dart -v"
```

Expected: `All tests passed!` (6 tests)

- [ ] **Commit:**

```bash
git add lib/core/services/premium_service.dart test/core/services/premium_service_test.dart
git commit -m "feat(premium): add PremiumService with SharedPreferences persistence + TDD"
```

---

## Task 7: Update `AuthState` + `AuthCubit` + auth tests

**Files:**
- Modify: `lib/features/auth/presentation/bloc/auth_state.dart`
- Modify: `lib/features/auth/presentation/bloc/auth_cubit.dart`
- Modify: `test/features/auth/presentation/bloc/auth_cubit_test.dart`

- [ ] **Update `auth_state.dart` — add `isPremium` to `AuthAuthenticated`:**

Replace the entire file content:

```dart
// lib/features/auth/presentation/bloc/auth_state.dart
part of 'auth_cubit.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthUnauthenticated extends AuthState {
  final String? error;
  const AuthUnauthenticated({this.error});
  @override
  List<Object?> get props => [error];
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final bool isPremium;
  const AuthAuthenticated(this.user, {this.isPremium = false});
  @override
  List<Object?> get props => [user, isPremium];
}
```

- [ ] **Update `auth_cubit.dart` — inject `PremiumService`, add `setPremium()`:**

Replace the entire file content:

```dart
// lib/features/auth/presentation/bloc/auth_cubit.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/premium_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final PremiumService _premiumService;

  AuthCubit(this._authRepository, this._premiumService)
      : super(const AuthUnauthenticated());

  Future<void> checkCurrentUser() async {
    await _premiumService.init();
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user, isPremium: _premiumService.isPremium));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthAuthenticating());
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (failure) => emit(AuthUnauthenticated(error: failure.message)),
      (user) => emit(
        AuthAuthenticated(user, isPremium: _premiumService.isPremium),
      ),
    );
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> setPremium(bool value) async {
    await _premiumService.setPremium(value);
    final s = state;
    if (s is AuthAuthenticated) {
      emit(AuthAuthenticated(s.user, isPremium: value));
    }
  }
}
```

- [ ] **Rewrite `auth_cubit_test.dart` to match new constructor and `isPremium` field:**

```dart
// test/features/auth/presentation/bloc/auth_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/features/auth/domain/entities/auth_user.dart';
import 'package:lifetime/features/auth/domain/repositories/auth_repository.dart';
import 'package:lifetime/features/auth/presentation/bloc/auth_cubit.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late PremiumService premiumService;

  const tUser = AuthUser(
    id: 'goog-1',
    email: 'test@gmail.com',
    displayName: 'Test User',
    photoUrl: null,
    accessToken: 'token-abc',
  );

  setUp(() {
    mockRepo = MockAuthRepository();
    SharedPreferences.setMockInitialValues({});
    premiumService = PremiumService();
  });

  AuthCubit _makeCubit() => AuthCubit(mockRepo, premiumService);

  test('initial state is AuthUnauthenticated', () {
    expect(_makeCubit().state, const AuthUnauthenticated());
  });

  group('checkCurrentUser', () {
    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: false) when session exists and no premium stored',
      setUp: () =>
          when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser),
      build: _makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthAuthenticated(tUser, isPremium: false)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: true) when session exists and premium stored',
      setUp: () {
        SharedPreferences.setMockInitialValues({'is_premium': true});
        premiumService = PremiumService();
        when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser);
      },
      build: _makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthAuthenticated(tUser, isPremium: true)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated when no session',
      setUp: () =>
          when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => null),
      build: _makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  group('signInWithGoogle', () {
    blocTest<AuthCubit, AuthState>(
      'emits [Authenticating, Authenticated(isPremium: false)] on success',
      setUp: () => when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) async => const Right(tUser)),
      build: _makeCubit,
      act: (c) => c.signInWithGoogle(),
      expect: () => [
        const AuthAuthenticating(),
        const AuthAuthenticated(tUser, isPremium: false),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [Authenticating, Unauthenticated] when cancelled',
      setUp: () => when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) async =>
              const Left(AuthFailure('Sign-in cancelled'))),
      build: _makeCubit,
      act: (c) => c.signInWithGoogle(),
      expect: () => [
        const AuthAuthenticating(),
        const AuthUnauthenticated(error: 'Sign-in cancelled'),
      ],
    );
  });

  group('signOut', () {
    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated after sign out',
      setUp: () => when(() => mockRepo.signOut())
          .thenAnswer((_) async => const Right(unit)),
      build: _makeCubit,
      seed: () => const AuthAuthenticated(tUser),
      act: (c) => c.signOut(),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  group('setPremium', () {
    blocTest<AuthCubit, AuthState>(
      'emits AuthAuthenticated(isPremium: true) when called with true',
      build: _makeCubit,
      seed: () => const AuthAuthenticated(tUser, isPremium: false),
      act: (c) => c.setPremium(true),
      expect: () => [const AuthAuthenticated(tUser, isPremium: true)],
    );

    blocTest<AuthCubit, AuthState>(
      'does not emit when state is Unauthenticated',
      build: _makeCubit,
      seed: () => const AuthUnauthenticated(),
      act: (c) => c.setPremium(true),
      expect: () => [],
    );
  });
}
```

- [ ] **Run the auth tests:**

```bash
powershell.exe -Command "flutter test test/features/auth/presentation/bloc/auth_cubit_test.dart -v"
```

Expected: `All tests passed!` (8 tests)

- [ ] **Commit:**

```bash
git add lib/features/auth/presentation/bloc/auth_state.dart lib/features/auth/presentation/bloc/auth_cubit.dart test/features/auth/presentation/bloc/auth_cubit_test.dart
git commit -m "feat(auth): add isPremium field to AuthAuthenticated and PremiumService wiring"
```

---

## Task 8: Refactor `MilestoneRepositoryImpl` to hybrid (TDD)

**Files:**
- Modify: `test/data/repositories/milestone_repository_impl_test.dart`
- Modify: `lib/data/repositories/milestone_repository_impl.dart`

### Step 8a — Rewrite the test file

- [ ] **Replace the entire content of `test/data/repositories/milestone_repository_impl_test.dart`:**

```dart
// test/data/repositories/milestone_repository_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/data/datasources/milestone_remote_datasource.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/data/repositories/milestone_repository_impl.dart';
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';

class MockIsarMilestoneDataSource extends Mock
    implements IsarMilestoneDataSource {}

class MockMilestoneRemoteDataSource extends Mock
    implements MilestoneRemoteDataSource {}

class MockPremiumService extends Mock implements PremiumService {}

void main() {
  late MockIsarMilestoneDataSource mockLocal;
  late MockMilestoneRemoteDataSource mockRemote;
  late MockPremiumService mockPremium;
  late MilestoneRepositoryImpl repository;

  final tDate = DateTime(2026, 4, 26);
  const tUserNote = 'Celebré mi 30 cumpleaños con amigos.';
  const tLocationName = 'Madrid';

  final tBiographerResult =
      (title: 'Mi 30 cumpleaños', narrative: 'Fue un día especial.');

  final tMilestoneModel = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const ['Ana'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    category: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  final tCollection = MilestoneCollection.fromMilestone(
    tMilestoneModel,
    SyncStatus.synced,
  );

  final tPendingCollection = MilestoneCollection.fromMilestone(
    tMilestoneModel,
    SyncStatus.pending,
  );

  setUp(() {
    mockLocal = MockIsarMilestoneDataSource();
    mockRemote = MockMilestoneRemoteDataSource();
    mockPremium = MockPremiumService();
    repository = MilestoneRepositoryImpl(
      mockLocal,
      mockRemote,
      mockPremium,
      () => 'user-1',
    );
  });

  void stubPremium(bool value) {
    when(() => mockPremium.isPremium).thenReturn(value);
  }

  void stubBiographerSuccess() {
    when(() => mockRemote.callBiographerNarrative(
          userNote: any(named: 'userNote'),
          date: any(named: 'date'),
          location: any(named: 'location'),
          imageBase64: any(named: 'imageBase64'),
        )).thenAnswer((_) async => tBiographerResult);
  }

  // ─── getMilestones ────────────────────────────────────────────────────────

  group('getMilestones', () {
    test('returns local data when Isar is non-empty (free user)', () async {
      stubPremium(false);
      when(() => mockLocal.fetchAll())
          .thenAnswer((_) async => [tCollection]);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) {
        expect(list, hasLength(1));
        expect(list.first.id, equals('ms-1'));
      });
    });

    test('returns empty list for free user with empty Isar', () async {
      stubPremium(false);
      when(() => mockLocal.fetchAll()).thenAnswer((_) async => []);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result, equals(const Right(<dynamic>[])));
    });

    test('seeds from Supabase when premium + Isar empty, then returns those milestones',
        () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll()).thenAnswer((_) async => []);
      when(() => mockRemote.fetchMilestones())
          .thenAnswer((_) async => [tMilestoneModel]);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      final result = await repository.getMilestones();

      verify(() => mockRemote.fetchMilestones()).called(1);
      verify(() => mockLocal.upsert(any())).called(1);
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (list) {
        expect(list, hasLength(1));
      });
    });

    test('does NOT call remote when premium + Isar non-empty', () async {
      stubPremium(true);
      when(() => mockLocal.fetchAll())
          .thenAnswer((_) async => [tCollection]);

      final result = await repository.getMilestones();

      verifyNever(() => mockRemote.fetchMilestones());
      expect(result.isRight(), isTrue);
    });
  });

  // ─── createMilestone — Free user ──────────────────────────────────────────

  group('createMilestone — free user', () {
    setUp(() => stubPremium(false));

    test('never calls biographer or remote insert', () async {
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tPendingCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      verifyNever(() => mockRemote.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
            imageBase64: any(named: 'imageBase64'),
          ));
      verifyNever(() => mockRemote.insertMilestone(any()));
    });

    test('calls local.upsert with a pending collection', () async {
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        participants: ['Ana'],
      );

      expect(result.isRight(), isTrue);
      expect(captured, isNotNull);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
      expect(captured!.description, equals(tUserNote));
      expect(captured!.locationName, equals(tLocationName));
    });

    test('title uses date-based fallback', () async {
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      await repository.createMilestone(
        userNote: 'Nota libre.',
        eventDate: DateTime(2026, 4, 26),
      );

      expect(captured!.title, contains('26'));
      expect(captured!.title, contains('2026'));
    });
  });

  // ─── createMilestone — Premium online ────────────────────────────────────

  group('createMilestone — premium online', () {
    setUp(() => stubPremium(true));

    test('calls biographer + remote insert, upserts locally as synced', () async {
      stubBiographerSuccess();
      when(() => mockRemote.insertMilestone(any()))
          .thenAnswer((_) async => tMilestoneModel);
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        participants: ['Ana'],
      );

      expect(result, Right(tMilestoneModel));
      expect(captured!.syncStatus, equals(SyncStatus.synced));
    });

    test('insert map contains POINT WKT when lat/lng provided', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('insert map omits location_coords when lat/lng are null', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(capturedData!.containsKey('location_coords'), isFalse);
    });
  });

  // ─── createMilestone — Premium offline ───────────────────────────────────

  group('createMilestone — premium offline', () {
    setUp(() => stubPremium(true));

    test('returns Right and saves as pending when remote insert throws', () async {
      stubBiographerSuccess();
      when(() => mockRemote.insertMilestone(any()))
          .thenThrow(Exception('Network error'));
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
    });

    test('saves as pending when biographer also throws (full offline)', () async {
      when(() => mockRemote.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
            imageBase64: any(named: 'imageBase64'),
          )).thenThrow(Exception('Biographer unreachable'));
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
      verify(() => mockLocal.upsert(any())).called(1);
      verifyNever(() => mockRemote.insertMilestone(any()));
    });
  });

  // ─── deleteMilestone ─────────────────────────────────────────────────────

  group('deleteMilestone', () {
    test('free user: deletes from local only', () async {
      stubPremium(false);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1')).called(1);
      verifyNever(() => mockRemote.deleteMilestone(any()));
    });

    test('premium user: deletes from local and attempts remote', () async {
      stubPremium(true);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});
      when(() => mockRemote.deleteMilestone(any())).thenAnswer((_) async {});

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
      verify(() => mockLocal.deleteById('ms-1')).called(1);
      verify(() => mockRemote.deleteMilestone('ms-1')).called(1);
    });

    test('premium user: still returns Right when remote delete throws', () async {
      stubPremium(true);
      when(() => mockLocal.deleteById(any())).thenAnswer((_) async {});
      when(() => mockRemote.deleteMilestone(any()))
          .thenThrow(Exception('Network error'));

      final result = await repository.deleteMilestone('ms-1');

      expect(result.isRight(), isTrue);
    });
  });

  // ─── updateMilestone ──────────────────────────────────────────────────────

  group('updateMilestone', () {
    test('free user: updates local as pending', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tPendingCollection);

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Relato actualizado.',
      );

      expect(result.isRight(), isTrue);
      verifyNever(() => mockRemote.updateMilestone(any(), any()));
    });

    test('premium online: updates local + remote, upserts as synced', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Relato actualizado.',
        locationName: 'Barcelona',
        latitude: 41.3851,
        longitude: 2.1734,
      );

      expect(result, Right(tMilestoneModel));
      verify(() => mockRemote.updateMilestone('ms-1', any())).called(1);
    });

    test('update map has correct WKT longitude-first order', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      when(() => mockLocal.upsert(any()))
          .thenAnswer((_) async => tCollection);
      Map<String, dynamic>? capturedData;
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenAnswer((inv) async {
        capturedData = inv.positionalArguments[1] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.updateMilestone(
        id: 'ms-1',
        description: 'WKT test.',
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('premium offline: saves locally as pending when remote throws', () async {
      stubPremium(true);
      when(() => mockLocal.fetchById('ms-1'))
          .thenAnswer((_) async => tCollection);
      MilestoneCollection? captured;
      when(() => mockLocal.upsert(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MilestoneCollection;
        return captured!;
      });
      when(() => mockRemote.updateMilestone(any(), any()))
          .thenThrow(Exception('Network error'));

      final result = await repository.updateMilestone(
        id: 'ms-1',
        description: 'Offline update.',
      );

      expect(result.isRight(), isTrue);
      expect(captured!.syncStatus, equals(SyncStatus.pending));
    });

    test('returns Left(DatabaseFailure) when item not found locally', () async {
      stubPremium(false);
      when(() => mockLocal.fetchById(any())).thenAnswer((_) async => null);

      final result = await repository.updateMilestone(
        id: 'nonexistent',
        description: 'test',
      );

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<DatabaseFailure>()), (_) => fail('Expected Left'));
    });
  });
}
```

- [ ] **Run to confirm tests fail (repository not yet refactored):**

```bash
powershell.exe -Command "flutter test test/data/repositories/milestone_repository_impl_test.dart -v 2>&1 | Select-String -Pattern 'FAIL|Error' | Select-Object -First 5"
```

Expected: compile errors because `MilestoneRepositoryImpl` still takes 1 constructor arg.

### Step 8b — Implement the hybrid repository

- [ ] **Replace the entire content of `lib/data/repositories/milestone_repository_impl.dart`:**

```dart
// lib/data/repositories/milestone_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/failures/failure.dart';
import '../../core/services/premium_service.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/isar_milestone_datasource.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import '../../features/milestones/data/models/local/media_asset_embed.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final IsarMilestoneDataSource _local;
  final MilestoneRemoteDataSource _remote;
  final PremiumService _premium;
  final String Function() _getUserId;

  MilestoneRepositoryImpl(
    this._local,
    this._remote,
    this._premium,
    this._getUserId,
  );

  static const _uuid = Uuid();

  // ── getMilestones ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Milestone>>> getMilestones() async {
    try {
      final local = await _local.fetchAll();
      if (local.isNotEmpty) {
        return Right(local.map((c) => c.toDomain()).toList());
      }
      if (!_premium.isPremium) {
        return const Right([]);
      }
      // Premium + empty local → seed from Supabase
      final remoteModels = await _remote.fetchMilestones();
      for (final model in remoteModels) {
        await _local.upsert(
            MilestoneCollection.fromMilestone(model, SyncStatus.synced));
      }
      return Right(remoteModels.cast<Milestone>());
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── getMilestoneById ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Milestone>> getMilestoneById(String id) async {
    try {
      final local = await _local.fetchById(id);
      if (local != null) return Right(local.toDomain());
      if (!_premium.isPremium) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }
      final model = await _remote.fetchMilestoneById(id);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message, code: e.code));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── createMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Milestone>> createMilestone({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
    String? driveFileId,
    String? imageBase64,
  }) async {
    final userId = _getUserId();

    if (!_premium.isPremium) {
      return _saveLocalOnly(
        title: _dateTitle(eventDate),
        description: userNote,
        userId: userId,
        userNote: userNote,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        participants: participants,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
    }

    // Premium path — try remote, fall back to local on any error
    String? title;
    String? narrative;
    try {
      final bio = await _remote.callBiographerNarrative(
        userNote: userNote,
        date: eventDate,
        location: locationName,
        imageBase64: imageBase64,
      );
      title = bio.title;
      narrative = bio.narrative;

      final insertData = MilestoneModel.toInsertMap(
        title: title,
        description: narrative,
        participants: participants,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
      final remoteModel = await _remote.insertMilestone(insertData);
      await _local.upsert(
          MilestoneCollection.fromMilestone(remoteModel, SyncStatus.synced));
      return Right(remoteModel);
    } on FormatException {
      return const Left(BiographerFailure());
    } catch (_) {
      return _saveLocalOnly(
        title: title ?? _dateTitle(eventDate),
        description: narrative ?? userNote,
        userId: userId,
        userNote: userNote,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        participants: participants,
        isPublic: isPublic,
        driveFileId: driveFileId,
      );
    }
  }

  // ── deleteMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteMilestone(String id) async {
    try {
      await _local.deleteById(id);
      if (_premium.isPremium) {
        try {
          await _remote.deleteMilestone(id);
        } catch (_) {
          // Best-effort remote delete — local deletion is source of truth
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── updateMilestone ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Milestone>> updateMilestone({
    required String id,
    required String description,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final existing = await _local.fetchById(id);
      if (existing == null) {
        return Left(DatabaseFailure('Milestone $id not found'));
      }

      existing
        ..description = description
        ..syncStatus = SyncStatus.pending;
      if (locationName != null) existing.locationName = locationName;
      if (latitude != null) existing.latitude = latitude;
      if (longitude != null) existing.longitude = longitude;
      await _local.upsert(existing);

      if (_premium.isPremium) {
        try {
          final updateData = MilestoneModel.toUpdateMap(
            description: description,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
          );
          final remoteModel = await _remote.updateMilestone(id, updateData);
          await _local.upsert(MilestoneCollection.fromMilestone(
              remoteModel, SyncStatus.synced));
          return Right(remoteModel);
        } catch (_) {
          // Remote failed — already saved locally as pending
        }
      }

      return Right(existing.toDomain());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Either<Failure, Milestone>> _saveLocalOnly({
    required String title,
    required String? description,
    required String userId,
    required String userNote,
    required DateTime eventDate,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required String category,
    required List<String> participants,
    required bool isPublic,
    required String? driveFileId,
  }) async {
    try {
      final collection = MilestoneCollection()
        ..id = _uuid.v4()
        ..userId = userId
        ..title = title
        ..description = description
        ..participants = List<String>.from(participants)
        ..eventDate = eventDate
        ..locationName = locationName
        ..latitude = latitude
        ..longitude = longitude
        ..category = category
        ..isPublic = isPublic
        ..createdAt = DateTime.now()
        ..driveFileId = driveFileId
        ..syncStatus = SyncStatus.pending
        ..media = [];
      final saved = await _local.upsert(collection);
      return Right(saved.toDomain());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  static String _dateTitle(DateTime date) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return 'Hito del ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
```

- [ ] **Run the repository tests:**

```bash
powershell.exe -Command "flutter test test/data/repositories/milestone_repository_impl_test.dart -v"
```

Expected: `All tests passed!`

- [ ] **Run the full test suite to check for regressions:**

```bash
powershell.exe -Command "flutter test -v 2>&1 | tail -20"
```

Expected: all tests pass (only auth cubit tests and repository tests may show changes — the rest should be unaffected).

- [ ] **Commit:**

```bash
git add lib/data/repositories/milestone_repository_impl.dart test/data/repositories/milestone_repository_impl_test.dart
git commit -m "feat(repo): refactor MilestoneRepositoryImpl to local-first hybrid"
```

---

## Task 9: Update DI container

**Files:** Modify `lib/injection_container.dart`

- [ ] **Replace the entire content of `lib/injection_container.dart`:**

```dart
// lib/injection_container.dart
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

const _googleWebClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

Future<void> init() async {
  // ─── Isar ──────────────────────────────────────────────────────────────────
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [MilestoneCollectionSchema],
    directory: dir.path,
  );
  sl.registerSingleton<Isar>(isar);

  // ─── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<PremiumService>(() => PremiumService());
  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(
      clientId: kIsWeb ? _googleWebClientId : null,
      scopes: ['https://www.googleapis.com/auth/drive.file'],
    ),
  );

  // ─── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<IsarMilestoneDataSource>(
    () => IsarMilestoneDataSourceImpl(sl()),
  );
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
      sl(),                                          // IsarMilestoneDataSource
      sl(),                                          // MilestoneRemoteDataSource
      sl(),                                          // PremiumService
      () => sl<SupabaseClient>().auth.currentUser?.id ?? '',
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
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl(), sl()));  // +PremiumService
}
```

- [ ] **Run the analyzer to catch any import or type errors:**

```bash
powershell.exe -Command "flutter analyze lib/injection_container.dart"
```

Expected: `No issues found!`

- [ ] **Commit:**

```bash
git add lib/injection_container.dart
git commit -m "chore(di): wire Isar, IsarMilestoneDataSource, PremiumService into container"
```

---

## Task 10: Add Premium switch to `SettingsPage`

**Files:** Modify `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Add the `_PremiumTile` widget class at the bottom of the file (before the `_SectionHeader` class):**

```dart
// ── Premium sync tile ─────────────────────────────────────────────────────

class _PremiumTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (ctx, state) {
        final isPremium = state is AuthAuthenticated && state.isPremium;
        return SwitchListTile(
          secondary: Icon(
            Icons.cloud_sync_outlined,
            color: isPremium ? AppTheme.navy : Colors.grey,
          ),
          title: const Text('Sincronización en la Nube'),
          subtitle: Text(
            isPremium
                ? 'Activa · Biographer IA + Google Drive'
                : 'Desactivada · Solo almacenamiento local',
            style: TextStyle(
              color: isPremium ? AppTheme.navy : Colors.grey.shade600,
            ),
          ),
          value: isPremium,
          activeColor: AppTheme.navy,
          onChanged: (v) => ctx.read<AuthCubit>().setPremium(v),
        );
      },
    );
  }
}
```

- [ ] **In `_SettingsView.build()`, add the Premium section above "Cuenta". Find this block in the `ListView` children:**

```dart
            _SectionHeader(label: 'Tus datos'),
            _ExportTile(),
            const Divider(height: 32, indent: 16, endIndent: 16),
            _SectionHeader(label: 'Cuenta'),
            _SignOutTile(),
```

Replace it with:

```dart
            _SectionHeader(label: 'Plan'),
            _PremiumTile(),
            const Divider(height: 32, indent: 16, endIndent: 16),
            _SectionHeader(label: 'Tus datos'),
            _ExportTile(),
            const Divider(height: 32, indent: 16, endIndent: 16),
            _SectionHeader(label: 'Cuenta'),
            _SignOutTile(),
```

- [ ] **Run the analyzer on the settings page:**

```bash
powershell.exe -Command "flutter analyze lib/features/settings/presentation/pages/settings_page.dart"
```

Expected: `No issues found!`

- [ ] **Commit:**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(settings): add Premium sync SwitchListTile"
```

---

## Task 11: Final validation

- [ ] **Run the full analyzer:**

```bash
powershell.exe -Command "flutter analyze"
```

Expected: `No issues found!`

- [ ] **Run all tests:**

```bash
powershell.exe -Command "flutter test -v 2>&1 | tail -30"
```

Expected: all tests pass. Note the test count — it should be higher than before Task 1.

- [ ] **Verify the import path in `isar_milestone_datasource.dart` is correct for the project structure:**

The relative import `'../features/milestones/data/models/local/milestone_collection.dart'` assumes the file is at `lib/data/datasources/`. From there, `..` goes to `lib/data/`, then `features/milestones/data/models/local/milestone_collection.dart`. Verify this resolves correctly, or change to a package import:

```dart
import 'package:lifetime/features/milestones/data/models/local/milestone_collection.dart';
```

- [ ] **Smoke-test on Chrome (optional but recommended):**

```bash
powershell.exe -Command "flutter run -d chrome --web-port=5000 --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key> --dart-define=GOOGLE_CLIENT_ID=<id>"
```

With Premium OFF: create a milestone — timeline should load instantly from Isar with no Biographer call in the console.  
With Premium ON: create a milestone — Biographer AI call should appear in console, then sync to Supabase.

- [ ] **Final commit:**

```bash
git add -A
git commit -m "feat(task-26): local-first engine — Isar DB, PremiumService, hybrid repository"
```
