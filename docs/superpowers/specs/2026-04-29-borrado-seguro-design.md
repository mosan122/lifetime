# Borrado Seguro e Integral — Design Spec

**Date:** 2026-04-29
**Status:** Approved

---

## Problem

`deleteMilestone` currently removes only the Isar record and (if Premium) the Supabase row. Two cleanup gaps remain:

1. Local media folder at `LifeTime/YYYY/MM/DD/{milestoneId}/` is never deleted.
2. The associated Google Drive file is never deleted.

The signature also lacks an access token, so Drive deletion cannot be performed today.

---

## Architecture

Five-layer cleanup chain, always local-first to avoid orphaned remote data on crash:

```
_DetailScaffold
  └─ DeleteMilestoneCubit.delete(id, {accessToken})
       └─ DeleteMilestoneUseCase(DeleteMilestoneParams(id, {accessToken}))
            └─ MilestoneRepositoryImpl.deleteMilestone(id, {accessToken})
                 ├─ IsarMilestoneDataSource.deleteById(id)
                 ├─ LocalMediaStore.deleteFolder(date, id)       ← new
                 ├─ MilestoneRemoteDataSource.deleteMilestone(id) [Premium]
                 └─ DriveRepository.deleteFile(fileId, accessToken) [Premium + Drive]  ← new
```

---

## New Component: `LocalMediaStore`

Thin injectable abstraction over `dart:io` so the repository can be tested without touching the real filesystem.

```dart
abstract class LocalMediaStore {
  /// Deletes LifeTime/YYYY/MM/DD/{milestoneId}/ under the app documents dir.
  /// No-op (no error) if the folder does not exist.
  Future<void> deleteFolder(DateTime date, String milestoneId);
}
```

Implementation path: `lib/core/services/local_media_store.dart`

The production implementation resolves the base path with `getApplicationDocumentsDirectory()` and calls `Directory(...).delete(recursive: true)`, catching `FileSystemException` for the missing-directory case.

On web (`kIsWeb`), the implementation is a no-op stub registered in `injection_container.dart` alongside the existing Isar web stub pattern.

---

## Google Drive Deletion

`GoogleDriveDataSource` gains a new method:

```dart
Future<void> deleteFile({
  required String fileId,
  required String accessToken,
});
```

Implementation: calls `api.files.delete(fileId)` via the existing `_AuthenticatedClient` pattern. Errors are propagated as `DriveException`.

`DriveRepository` and `DriveRepositoryImpl` gain the matching method, wrapping exceptions in `Left(NetworkFailure(...))`.

Drive deletion is **best-effort**: if it throws, the repository logs and continues — the record is already gone from Isar and Supabase.

---

## Repository Cleanup Sequence

```dart
Future<Either<Failure, void>> deleteMilestone(
  String id, {
  String? accessToken,
}) async {
  try {
    final existing = await _local.fetchById(id); // for date + driveFileId
    await _local.deleteById(id);
    if (existing != null) {
      await _localMedia.deleteFolder(existing.eventDate, id); // best-effort
    }
    if (_premium.isPremium) {
      try { await _remote.deleteMilestone(id); } catch (_) {}
      if (existing?.driveFileId != null && accessToken != null) {
        try {
          await _drive.deleteFile(
            fileId: existing!.driveFileId!,
            accessToken: accessToken,
          );
        } catch (_) {}
      }
    }
    return const Right(null);
  } catch (e) {
    return Left(NetworkFailure(e.toString()));
  }
}
```

`MilestoneRepositoryImpl` gains two new constructor dependencies — `DriveRepository` (5th arg) and `LocalMediaStore` (6th arg) — appended after the existing four args, injected via `get_it`.

---

## Signature Changes (propagate upward)

| Layer | Change |
|---|---|
| `MilestoneRepository` interface | `deleteMilestone(id, {String? accessToken})` |
| `DeleteMilestoneParams` | adds `final String? accessToken` |
| `DeleteMilestoneUseCase.call` | passes `accessToken` through |
| `DeleteMilestoneCubit.delete` | `delete(String id, {String? accessToken})` |
| `_DetailScaffold._confirmDelete` | passes `this.accessToken` to cubit |

---

## UI: No Changes Needed

`MilestoneDetailPage` already has the delete button with AlertDialog confirmation and pops with `'deleted'` on success. The timeline already calls `loadTimeline()` on any non-null pop result.

---

## Injection Container Changes

```dart
// LocalMediaStore — native vs web
if (!kIsWeb) {
  sl.registerLazySingleton<LocalMediaStore>(() => LocalMediaStoreImpl());
} else {
  sl.registerLazySingleton<LocalMediaStore>(() => _WebLocalMediaStore());
}

// MilestoneRepositoryImpl gains 2 new deps
sl.registerLazySingleton<MilestoneRepository>(
  () => MilestoneRepositoryImpl(
    sl<IsarMilestoneDataSource>(),
    sl<MilestoneRemoteDataSource>(),
    sl<PremiumService>(),
    () => Supabase.instance.client.auth.currentUser?.id ?? '',
    sl<DriveRepository>(),    // new
    sl<LocalMediaStore>(),    // new
  ),
);
```

---

## Testing

**New test group: `deleteMilestone` extended**

Mocks: `MockIsarMilestoneDataSource`, `MockMilestoneRemoteDataSource`, `MockPremiumService`, `MockDriveRepository` (new), `MockLocalMediaStore` (new).

Key test cases:
1. **Free user**: `deleteById` called + `deleteFolder` called with correct `(tDate, 'ms-1')` · no Drive/Supabase calls.
2. **Premium user with Drive file**: all four calls made; Drive deletion uses `driveFileId` from the fetched collection.
3. **Folder missing (throws FileSystemException)**: `deleteFolder` still returns without propagating; `Right(null)` returned.

The test verifies "no new record is created" implicitly — `upsert` is never called during delete.

---

## Out of Scope

- Saving media to the `LifeTime/YYYY/MM/DD/{milestoneId}/` folder during creation (a future task). Deletion is best-effort today; if the folder doesn't exist the operation is a clean no-op.
- Google Drive folder hierarchy mirroring the `LifeTime/YYYY/MM/DD` path — Drive uses a flat `LifeTime_App` folder today.
