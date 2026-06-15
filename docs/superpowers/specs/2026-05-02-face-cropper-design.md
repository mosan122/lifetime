# Face Cropper — Design Spec
_2026-05-02_

## Objetivo

Implementar un `FaceCropperService` reutilizable que gestione el flujo completo **pick → crop circular 1:1 → save local** para asignar fotos de perfil a las `Person` del sistema centralizado de identidades.

El servicio se invoca desde dos puntos:
- **`ManagePeoplePage`** — al tocar el avatar de una persona.
- **`AddMilestonePage`** — al tocar el badge `+` sobre el avatar vacío de un participante; en este caso el bottom sheet incluye las imágenes ya adjuntadas al hito.

---

## Arquitectura

### Nuevos archivos

```
lib/
  domain/services/
    face_cropper_service.dart            ← abstract interface (dominio)
  data/services/
    face_cropper_service_impl.dart       ← implementación (image_picker + image_cropper + I/O)
  features/milestones/presentation/widgets/
    face_source_bottom_sheet.dart        ← selector de fuente reutilizable
    person_avatar_badge.dart             ← avatar circular con badge '+' reutilizable
```

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `pubspec.yaml` | añadir `image_cropper: ^7.0.0` |
| `android/app/src/main/AndroidManifest.xml` | permisos galería + cámara |
| `ios/Runner/Info.plist` | `NSPhotoLibraryUsageDescription` + `NSCameraUsageDescription` |
| `lib/injection_container.dart` | registrar `FaceCropperService` como `LazySingleton` |
| `lib/features/settings/presentation/pages/manage_people_page.dart` | tap avatar → bottom sheet |
| `lib/features/milestones/presentation/pages/add_milestone_page.dart` | usar `PersonAvatarBadge` |
| `lib/core/failures/failure.dart` | añadir failures tipados de face crop |

### Sin cambio de schema Isar
`PersonCollection` ya tiene `faceImagePath` y `driveFaceFileId`. No hay migración.

---

## Interfaz del Servicio

```dart
// lib/domain/services/face_cropper_service.dart
// FaceImageSource vive en este mismo archivo (dominio puro, sin dependencias externas).
enum FaceImageSource { gallery, camera, milestoneImage }

abstract class FaceCropperService {
  /// Lanza el picker según [source] y el cropper nativo (circle, 1:1).
  /// Cuando [source] == milestoneImage, [milestoneImagePath] debe ser no nulo;
  /// en ese caso el picker se omite y el cropper recibe el archivo directamente.
  Future<Either<Failure, File>> pickAndCrop({
    required FaceImageSource source,
    String? milestoneImagePath,
  });

  /// Copia [croppedFile] a <appDocs>/faces/<personId>.jpg,
  /// actualiza faceImagePath en Isar y devuelve la Person actualizada.
  Future<Either<Failure, Person>> saveForPerson({
    required String personId,
    required File croppedFile,
  });
}
```

---

## Flujo de Datos

```
Widget
  │
  ├─ muestra FaceSourceBottomSheet(milestoneMediaItems?)
  │      └─ usuario elige fuente → FaceImageSource enum
  │
  ├─ service.pickAndCrop(source, milestoneImagePath?)
  │      ├─ image_picker → XFile           (galería / cámara)
  │      │  o File directo                 (imagen del hito)
  │      ├─ image_cropper → CropStyle.circle, ratio 1:1 → File temporal
  │      └─ Either<Failure, File>
  │
  └─ service.saveForPerson(personId, croppedFile)
         ├─ copia a <appDocs>/faces/<personId>.jpg (sobreescribe si existe)
         ├─ IsarPersonDataSource.upsert(person..faceImagePath = path)
         └─ Either<Failure, Person>
```

### Enum de fuente
`FaceImageSource` se define en `face_cropper_service.dart` (dominio). El bottom sheet lo devuelve al caller junto con la ruta opcional del hito; el caller invoca `pickAndCrop` con esos valores.

---

## UI

### `FaceSourceBottomSheet`

```
┌──────────────────────────────┐
│  Foto de perfil              │  ← título, estilo AppTheme
│  ─────────────────────────── │
│  [📷 Cámara]  [🖼 Galería]   │  ← siempre presentes
│                              │
│  ── Imágenes del hito ──     │  ← solo si milestoneMediaItems != null && no vacío
│  [ img1 ] [ img2 ] [ img3 ] │  ← horizontal scroll, thumbnails 72×72px cuadrados
└──────────────────────────────┘
```

- `showModalBottomSheet` con `BorderRadius.vertical(top: Radius.circular(20))`.
- Tema: `backgroundColor: AppTheme.cream`.
- Los videos se filtran del listado de imágenes del hito (extensiones `.mp4`, `.mov`, `.avi`).
- El bottom sheet devuelve `FaceImageSource` + ruta opcional al caller; el caller invoca el servicio.

### `PersonAvatarBadge`

```dart
PersonAvatarBadge({
  required String? faceImagePath,
  required String personName,
  required VoidCallback onAssignPhoto,
  double size = 44,
})
```

- `Stack`: `CircleAvatar` base + `Positioned` badge `⊕` (18px, navy sólido, icono `+` crema).
- Badge visible solo cuando `faceImagePath == null` o el archivo no existe.
- Usado en `AddMilestonePage` en la lista de participantes.

### `ManagePeoplePage`

- El `CircleAvatar` existente se envuelve en `GestureDetector(onTap: _assignPhoto)`.
- `_assignPhoto` abre `FaceSourceBottomSheet` sin `milestoneMediaItems`.
- Tras éxito: `setState((){})` — flujo existente sin cambios de arquitectura.
- El `PopupMenuButton` conserva "Borrar foto de perfil".

---

## Permisos

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Necesitamos acceso a tus fotos para asignar una foto de perfil.</string>
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para tomar una foto de perfil.</string>
```

---

## Manejo de Errores

### Nuevos Failures (`lib/core/failures/failure.dart`)
```dart
class FaceCropCancelledFailure extends Failure {}  // usuario canceló — sin SnackBar
class FaceCropPickFailure    extends Failure {}    // error image_picker — SnackBar rojo
class FaceCropSaveFailure    extends Failure {}    // error al escribir archivo — SnackBar rojo
```

### Tabla de casos límite

| Caso | Comportamiento |
|---|---|
| Usuario cancela el picker | `Left(FaceCropCancelledFailure())` — sin feedback visual |
| Usuario cancela el cropper | `Left(FaceCropCancelledFailure())` — sin feedback visual |
| Archivo de cara previo existente | Se sobreescribe en `faces/<personId>.jpg` |
| Imagen del hito es video | Filtrada del bottom sheet (no aparece) |
| `faceImagePath` apunta a archivo borrado | `CircleAvatar` muestra icono por defecto (`File(path).existsSync()` ya presente) |

---

## Dependencias a añadir

```yaml
# pubspec.yaml
image_cropper: ^7.0.0    # crop nativo circle 1:1 (uCrop/TOCropViewController)
```

`image_picker` ya está en `pubspec.yaml`.

---

## Fuera de scope

- Subida de la foto de cara a Google Drive (ya existe `driveFaceFileId` en el schema; se integra en el `CloudSyncService` en una iteración futura).
- Detección automática de cara con ML Kit.
- Recorte manual con UI Flutter puro.
