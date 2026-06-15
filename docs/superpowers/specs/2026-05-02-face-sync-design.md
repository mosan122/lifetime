# Face Sync — Design Spec

**Date:** 2026-05-02
**Feature:** Sincronización de fotos de perfil a Google Drive

---

## Goal

Extender el sistema de backup en la nube para que las fotos de perfil de las personas (`PersonCollection.faceImagePath`) se sincronicen automáticamente a Google Drive bajo la ruta `LifeTime/System/People/<personId>.jpg`, y se restauren automáticamente si el archivo local desaparece.

---

## Architecture

Tres cambios coordinados:

1. **`FaceCropperServiceImpl.saveForPerson()`** — Al guardar una nueva cara local, limpia `driveFaceFileId = null` para señalar al sync que hay una versión nueva pendiente de subida.

2. **`CloudSyncService`** — Recibe `IsarPersonDataSource` como nueva dependencia. `syncIfNeeded()` añade un paso al final que sube las caras pendientes. Un nuevo método `restoreMissingFaces()` descarga las caras que faltan localmente pero están en Drive.

3. **`ManagePeoplePage`** — Llama `restoreMissingFaces()` en background al cargar, para restaurar avatares en dispositivos nuevos o tras reinstalación.

---

## Drive Folder Structure

```
Google Drive (drive.file scope)
└── LifeTime/
    ├── YYYY/MM/DD/<milestoneId>/   ← ya existente
    └── System/
        └── People/
            ├── <personId>.jpg
            ├── <personId>.jpg
            └── ...
```

Los IDs de `System` y `People` se obtienen con `getOrCreateFolder()` — idempotente, funciona igual tanto en primera ejecución como en sincronizaciones posteriores.

El nombre del archivo en Drive usa el `id` de la persona (UUID), no el nombre, para evitar problemas con caracteres especiales.

---

## Changes Detail

### 1. `lib/data/services/face_cropper_service_impl.dart`

En `saveForPerson()`, al construir `PersonCollection` actualizado:

```dart
// Antes (preservaba el viejo Drive ID):
..driveFaceFileId = existing.driveFaceFileId

// Después (señala re-subida pendiente):
..driveFaceFileId = null
```

Sin cambios en la firma ni en los tests del servicio (el test de `saveForPerson` ya verifica que `faceImagePath` se actualiza; añadir verificación de `driveFaceFileId == null` en el test existente).

---

### 2. `lib/core/services/cloud_sync_service.dart`

**Constructor actualizado:**
```dart
CloudSyncService(
  PremiumService _premium,
  GoogleSignIn _googleSignIn,
  IsarMilestoneDataSource _milestones,
  IsarPersonDataSource _people,   // nuevo
)
```

**`syncIfNeeded(List<Milestone> milestones)` — pasos añadidos al final del try:**
```
systemId = getOrCreateFolder('System', parent: rootId)
peopleId = getOrCreateFolder('People', parent: systemId)
people    = await _people.fetchAll()
pendientes = people donde faceImagePath != null && driveFaceFileId == null
para cada persona en pendientes (uno a uno):
  f = File(faceImagePath!)
  si !f.existsSync() → continuar
  fileId = await driveService.uploadFile(f, peopleId)
  upsert PersonCollection con driveFaceFileId = fileId
```

**Nuevo método público `restoreMissingFaces()`:**
```
1. Igual que syncIfNeeded: auth lightweight → DriveApi → GoogleDriveService
2. people = await _people.fetchAll()
3. filtrar: driveFaceFileId != null && (faceImagePath == null || !File(path).existsSync())
4. para cada persona (uno a uno):
   destPath = '<appDocs>/faces/<personId>.jpg'
   await driveService.downloadFile(driveFaceFileId!, destPath)
   upsert PersonCollection con faceImagePath = destPath
5. errores individuales se capturan (try/catch por persona) y no detienen el resto
6. método best-effort: no lanza excepciones al caller
```

---

### 3. `lib/injection_container.dart`

```dart
sl.registerLazySingleton<CloudSyncService>(
  () => CloudSyncService(
    sl(),
    sl<GoogleSignIn>(),
    sl<IsarMilestoneDataSource>(),
    sl<IsarPersonDataSource>(),   // nuevo
  ),
);
```

---

### 4. `lib/features/settings/presentation/pages/manage_people_page.dart`

En el método `_load()` (o equivalente que devuelve el `Future<List<PersonCollection>>`), después de llamar `_ds.fetchAll()`, disparar `restoreMissingFaces()` en background:

```dart
Future<List<PersonCollection>> _load() async {
  final people = await _ds.fetchAll();
  unawaited(
    sl<CloudSyncService>().restoreMissingFaces().then((_) {
      if (mounted) setState(() {});
    }),
  );
  return people;
}
```

La UI no espera a la descarga — muestra el estado disponible y se redibuja si la descarga completa.

---

## Error Handling

- `syncIfNeeded` ya usa try/finally; los errores de personas individuales se capturan localmente y no interrumpen el loop.
- `restoreMissingFaces` captura errores por persona; si la auth falla (no hay cuenta, sin conexión), el método retorna silenciosamente.
- Sin Either aquí: ambos métodos son best-effort fire-and-forget desde el caller. Los errores se loguean con `print` (mismo patrón que el sync existente).

---

## Consistency Contract

| Evento | `faceImagePath` | `driveFaceFileId` | Resultado |
|---|---|---|---|
| Nueva cara guardada localmente | `<path>` | `null` | Sync sube en próximo ciclo |
| Sync completado | `<path>` | `<driveId>` | Sincronizado |
| Archivo local borrado | `null` o path inexistente | `<driveId>` | Restore descarga en próxima apertura |
| Cara cambiada (nueva foto) | `<newPath>` | `null` ← limpiado | Sync re-sube en próximo ciclo |

---

## Files Modified / Created

| Acción | Ruta |
|---|---|
| Modificar | `lib/data/services/face_cropper_service_impl.dart` |
| Modificar | `lib/core/services/cloud_sync_service.dart` |
| Modificar | `lib/injection_container.dart` |
| Modificar | `lib/features/settings/presentation/pages/manage_people_page.dart` |
| Modificar | `test/data/services/face_cropper_service_impl_test.dart` |

---

## Out of Scope

- Sincronización de caras en `AddMilestonePage` (ya existe el flujo de asignación local; el sync lo tomará desde el timeline cubit).
- Eliminación de archivos en Drive cuando se borra una persona (se cubre en el spec de Borrado Seguro ya documentado).
- Progreso/status visible de la sincronización de caras en la UI.
