# Face Cropper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar un `FaceCropperService` reutilizable (pick → crop circular 1:1 → save local) e integrarlo en `ManagePeoplePage` (tap avatar) y en `AddMilestonePage` (badge `+` sobre avatares vacíos de participantes), donde el bottom sheet de selección de fuente puede incluir las imágenes del hito actual.

**Architecture:** Clean Architecture en 3 capas. La interfaz `FaceCropperService` vive en `domain/services`; la implementación concreta en `data/services` inyecta `ImagePicker`, `ImageCropper` e `IsarPersonDataSource`. Dos widgets reutilizables (`PersonAvatarBadge`, `FaceSourceBottomSheet`) encapsulan la lógica de presentación.

**Tech Stack:** Flutter, `image_cropper ^7.0.0`, `image_picker ^1.0.7` (ya presente), `isar`, `dartz` Either, `get_it`, `mocktail`.

---

## File Map

| Acción | Ruta |
|---|---|
| Crear | `lib/domain/services/face_cropper_service.dart` |
| Crear | `lib/data/services/face_cropper_service_impl.dart` |
| Crear | `lib/features/milestones/presentation/widgets/person_avatar_badge.dart` |
| Crear | `lib/features/milestones/presentation/widgets/face_source_bottom_sheet.dart` |
| Crear | `test/data/services/face_cropper_service_impl_test.dart` |
| Crear | `test/features/milestones/presentation/widgets/person_avatar_badge_test.dart` |
| Crear | `test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart` |
| Modificar | `pubspec.yaml` — añadir `image_cropper` |
| Modificar | `android/app/src/main/AndroidManifest.xml` — permisos |
| Modificar | `ios/Runner/Info.plist` — permisos |
| Modificar | `lib/core/failures/failure.dart` — nuevos Failures |
| Modificar | `lib/injection_container.dart` — registrar servicio |
| Modificar | `lib/features/settings/presentation/pages/manage_people_page.dart` |
| Modificar | `lib/features/milestones/presentation/pages/add_milestone_page.dart` |

---

## Task 1: Dependency + Permisos de Plataforma

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1.1: Añadir `image_cropper` a pubspec.yaml**

En `pubspec.yaml`, dentro de `dependencies:`, añadir después de `image_picker`:

```yaml
  image_cropper: ^7.0.0
```

- [ ] **Step 1.2: Añadir permisos Android**

En `android/app/src/main/AndroidManifest.xml`, añadir dentro de `<manifest>` **antes** de `<application>`:

```xml
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 1.3: Añadir permisos iOS**

En `ios/Runner/Info.plist`, añadir justo antes de `</dict>`:

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Necesitamos acceso a tus fotos para asignar una foto de perfil.</string>
	<key>NSCameraUsageDescription</key>
	<string>Necesitamos acceso a la cámara para tomar una foto de perfil.</string>
```

- [ ] **Step 1.4: Instalar dependencias**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter pub get
```

Esperado: `Resolving dependencies...` sin errores, `image_cropper` aparece en el output.

- [ ] **Step 1.5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(face-crop): add image_cropper dep + platform permissions"
```

---

## Task 2: Nuevos Failure Types

**Files:**
- Modify: `lib/core/failures/failure.dart`

- [ ] **Step 2.1: Añadir failures al final del archivo**

Añadir al final de `lib/core/failures/failure.dart`:

```dart
class FaceCropCancelledFailure extends Failure {
  const FaceCropCancelledFailure() : super('Operación cancelada');
}

class FaceCropPickFailure extends Failure {
  const FaceCropPickFailure([String message = 'Error al seleccionar imagen'])
      : super(message);
}

class FaceCropSaveFailure extends Failure {
  const FaceCropSaveFailure([String message = 'Error al guardar foto de perfil'])
      : super(message);
}
```

- [ ] **Step 2.2: Verificar que el archivo compila**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/core/failures/failure.dart
```

Esperado: `No issues found!`

- [ ] **Step 2.3: Commit**

```bash
git add lib/core/failures/failure.dart
git commit -m "feat(face-crop): add FaceCrop failure types"
```

---

## Task 3: Domain — FaceCropperService Interface

**Files:**
- Create: `lib/domain/services/face_cropper_service.dart`

- [ ] **Step 3.1: Crear el archivo de dominio**

Crear `lib/domain/services/face_cropper_service.dart`:

```dart
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../failures/failure.dart';
import '../entities/person.dart';

enum FaceImageSource { gallery, camera, milestoneImage }

abstract class FaceCropperService {
  /// Lanza el picker según [source] y el cropper nativo (circle, 1:1).
  /// Cuando [source] == [FaceImageSource.milestoneImage],
  /// [milestoneImagePath] debe ser no nulo; el picker se omite.
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

- [ ] **Step 3.2: Verificar análisis**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/domain/services/face_cropper_service.dart
```

Esperado: `No issues found!`

- [ ] **Step 3.3: Commit**

```bash
git add lib/domain/services/face_cropper_service.dart
git commit -m "feat(face-crop): add FaceCropperService domain interface"
```

---

## Task 4: Data — FaceCropperServiceImpl + Tests

**Files:**
- Create: `lib/data/services/face_cropper_service_impl.dart`
- Create: `test/data/services/face_cropper_service_impl_test.dart`

- [ ] **Step 4.1: Escribir el test (failing)**

Crear `test/data/services/face_cropper_service_impl_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/services/face_cropper_service_impl.dart';
import 'package:lifetime/domain/services/face_cropper_service.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_person_datasource.dart';
import 'package:lifetime/features/milestones/data/models/local/person_collection.dart';

class MockImagePicker extends Mock implements ImagePicker {}
class MockImageCropper extends Mock implements ImageCropper {}
class MockIsarPersonDataSource extends Mock implements IsarPersonDataSource {}

class _FakePath extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePath(this._path);
  final String _path;
  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

class FakeXFile extends Fake implements XFile {
  @override
  final String path;
  FakeXFile(this.path);
}

class FakeCroppedFile extends Fake implements CroppedFile {
  @override
  final String path;
  FakeCroppedFile(this.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImagePicker picker;
  late MockImageCropper cropper;
  late MockIsarPersonDataSource personDs;
  late Directory tempDir;
  late FaceCropperServiceImpl sut;

  setUp(() async {
    picker = MockImagePicker();
    cropper = MockImageCropper();
    personDs = MockIsarPersonDataSource();
    tempDir = await Directory.systemTemp.createTemp('face_crop_test_');
    PathProviderPlatform.instance = _FakePath(tempDir.path);

    sut = FaceCropperServiceImpl(
      personDs: personDs,
      picker: picker,
      cropper: cropper,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('pickAndCrop – gallery', () {
    test('returns Right(File) when picker and cropper succeed', () async {
      final srcFile = File('${tempDir.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      final croppedFile = File('${tempDir.path}/cropped.jpg')..writeAsBytesSync([4, 5]);

      when(() => picker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => FakeXFile(srcFile.path));
      when(() => cropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            cropStyle: any(named: 'cropStyle'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => FakeCroppedFile(croppedFile.path));

      final result = await sut.pickAndCrop(source: FaceImageSource.gallery);

      expect(result.isRight(), isTrue);
    });

    test('returns Left(FaceCropCancelledFailure) when picker returns null', () async {
      when(() => picker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => null);

      final result = await sut.pickAndCrop(source: FaceImageSource.gallery);

      expect(result.fold((f) => f, (_) => null), isA<FaceCropCancelledFailure>());
    });

    test('returns Left(FaceCropCancelledFailure) when cropper returns null', () async {
      final srcFile = File('${tempDir.path}/src.jpg')..writeAsBytesSync([1]);
      when(() => picker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => FakeXFile(srcFile.path));
      when(() => cropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            cropStyle: any(named: 'cropStyle'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => null);

      final result = await sut.pickAndCrop(source: FaceImageSource.gallery);

      expect(result.fold((f) => f, (_) => null), isA<FaceCropCancelledFailure>());
    });

    test('returns Left(FaceCropPickFailure) when picker throws', () async {
      when(() => picker.pickImage(source: ImageSource.gallery))
          .thenThrow(Exception('permission denied'));

      final result = await sut.pickAndCrop(source: FaceImageSource.gallery);

      expect(result.fold((f) => f, (_) => null), isA<FaceCropPickFailure>());
    });
  });

  group('pickAndCrop – milestoneImage', () {
    test('skips picker and uses provided path directly', () async {
      final srcFile = File('${tempDir.path}/milestone.jpg')..writeAsBytesSync([9]);
      final cropped = File('${tempDir.path}/cropped.jpg')..writeAsBytesSync([8]);

      when(() => cropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            cropStyle: any(named: 'cropStyle'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => FakeCroppedFile(cropped.path));

      final result = await sut.pickAndCrop(
        source: FaceImageSource.milestoneImage,
        milestoneImagePath: srcFile.path,
      );

      verifyNever(() => picker.pickImage(source: any(named: 'source')));
      expect(result.isRight(), isTrue);
    });
  });

  group('saveForPerson', () {
    test('copies file, updates Isar, returns Right(Person)', () async {
      final croppedFile = File('${tempDir.path}/crop.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      final existing = PersonCollection()
        ..isarId = 1
        ..id = 'p1'
        ..name = 'Ana'
        ..faceImagePath = null
        ..driveFaceFileId = null;

      when(() => personDs.fetchById('p1')).thenAnswer((_) async => existing);
      when(() => personDs.upsert(any())).thenAnswer((inv) async {
        return inv.positionalArguments.first as PersonCollection;
      });

      final result = await sut.saveForPerson(personId: 'p1', croppedFile: croppedFile);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) {},
        (person) {
          expect(person.faceImagePath, contains('p1.jpg'));
        },
      );

      final destPath = '${tempDir.path}/faces/p1.jpg';
      expect(File(destPath).existsSync(), isTrue);
    });

    test('returns Left(FaceCropSaveFailure) when person not found', () async {
      final croppedFile = File('${tempDir.path}/crop.jpg')
        ..writeAsBytesSync([1]);
      when(() => personDs.fetchById('unknown')).thenAnswer((_) async => null);

      final result =
          await sut.saveForPerson(personId: 'unknown', croppedFile: croppedFile);

      expect(result.fold((f) => f, (_) => null), isA<FaceCropSaveFailure>());
    });
  });
}
```

- [ ] **Step 4.2: Ejecutar tests para confirmar que fallan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/data/services/face_cropper_service_impl_test.dart 2>&1 | head -20
```

Esperado: error de compilación — `FaceCropperServiceImpl` no existe aún.

- [ ] **Step 4.3: Implementar FaceCropperServiceImpl**

Crear `lib/data/services/face_cropper_service_impl.dart`:

```dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';

import '../../core/failures/failure.dart';
import '../../domain/entities/person.dart';
import '../../domain/services/face_cropper_service.dart';
import '../../features/milestones/data/datasources/isar_person_datasource.dart';
import '../../features/milestones/data/models/local/person_collection.dart';

class FaceCropperServiceImpl implements FaceCropperService {
  final ImagePicker _picker;
  final ImageCropper _cropper;
  final IsarPersonDataSource _personDs;

  FaceCropperServiceImpl({
    required IsarPersonDataSource personDs,
    ImagePicker? picker,
    ImageCropper? cropper,
  })  : _personDs = personDs,
        _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  @override
  Future<Either<Failure, File>> pickAndCrop({
    required FaceImageSource source,
    String? milestoneImagePath,
  }) async {
    try {
      File inputFile;

      if (source == FaceImageSource.milestoneImage) {
        assert(milestoneImagePath != null,
            'milestoneImagePath required for milestoneImage source');
        inputFile = File(milestoneImagePath!);
      } else {
        final xFile = await _picker.pickImage(
          source: source == FaceImageSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        if (xFile == null) return const Left(FaceCropCancelledFailure());
        inputFile = File(xFile.path);
      }

      final croppedFile = await _cropper.cropImage(
        sourcePath: inputFile.path,
        cropStyle: CropStyle.circle,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            toolbarColor: const Color(0xFF000080),
            toolbarWidgetColor: const Color(0xFFF5F5DC),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            hidesNavigationBar: true,
          ),
        ],
      );

      if (croppedFile == null) return const Left(FaceCropCancelledFailure());
      return Right(File(croppedFile.path));
    } catch (_) {
      return const Left(FaceCropPickFailure());
    }
  }

  @override
  Future<Either<Failure, Person>> saveForPerson({
    required String personId,
    required File croppedFile,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final facesDir = Directory('${appDir.path}/faces');
      if (!facesDir.existsSync()) await facesDir.create(recursive: true);

      final destPath = '${facesDir.path}/$personId.jpg';
      await croppedFile.copy(destPath);

      final existing = await _personDs.fetchById(personId);
      if (existing == null) return const Left(FaceCropSaveFailure());

      final updated = PersonCollection()
        ..isarId = existing.isarId
        ..id = existing.id
        ..name = existing.name
        ..faceImagePath = destPath
        ..driveFaceFileId = existing.driveFaceFileId;

      final saved = await _personDs.upsert(updated);
      return Right(saved.toDomain());
    } catch (_) {
      return const Left(FaceCropSaveFailure());
    }
  }
}
```

> **Nota:** `Color` se importa desde `dart:ui` implícitamente a través de `package:flutter/material.dart`. Si el archivo no tiene import Flutter añade: `import 'package:flutter/material.dart' show Color;`

- [ ] **Step 4.4: Ejecutar tests para confirmar que pasan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/data/services/face_cropper_service_impl_test.dart --reporter=expanded
```

Esperado: todos los tests en verde (`+8`).

- [ ] **Step 4.5: Análisis del proyecto**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/data/services/face_cropper_service_impl.dart
```

Esperado: `No issues found!`

- [ ] **Step 4.6: Commit**

```bash
git add lib/data/services/face_cropper_service_impl.dart test/data/services/face_cropper_service_impl_test.dart
git commit -m "feat(face-crop): implement FaceCropperServiceImpl with tests"
```

---

## Task 5: Widget — PersonAvatarBadge + Tests

**Files:**
- Create: `lib/features/milestones/presentation/widgets/person_avatar_badge.dart`
- Create: `test/features/milestones/presentation/widgets/person_avatar_badge_test.dart`

- [ ] **Step 5.1: Escribir tests del widget (failing)**

Crear `test/features/milestones/presentation/widgets/person_avatar_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/features/milestones/presentation/widgets/person_avatar_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra badge + cuando faceImagePath es null', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: null,
        personName: 'Ana',
        onAssignPhoto: () => tapped = true,
      ),
    ));

    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('no muestra badge cuando faceImagePath es ruta no vacía', (tester) async {
    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: '/some/path.jpg',
        personName: 'Juan',
        onAssignPhoto: () {},
      ),
    ));

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('muestra el nombre de la persona', (tester) async {
    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: null,
        personName: 'María',
        onAssignPhoto: () {},
      ),
    ));

    expect(find.text('María'), findsOneWidget);
  });
}
```

- [ ] **Step 5.2: Ejecutar tests para confirmar que fallan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/features/milestones/presentation/widgets/person_avatar_badge_test.dart 2>&1 | head -10
```

Esperado: error de compilación — widget no existe aún.

- [ ] **Step 5.3: Implementar PersonAvatarBadge**

Crear `lib/features/milestones/presentation/widgets/person_avatar_badge.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PersonAvatarBadge extends StatelessWidget {
  final String? faceImagePath;
  final String personName;
  final VoidCallback onAssignPhoto;
  final double size;

  const PersonAvatarBadge({
    super.key,
    required this.faceImagePath,
    required this.personName,
    required this.onAssignPhoto,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = faceImagePath != null &&
        faceImagePath!.isNotEmpty &&
        File(faceImagePath!).existsSync();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              CircleAvatar(
                radius: size / 2,
                backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                backgroundImage:
                    hasImg ? FileImage(File(faceImagePath!)) : null,
                child: hasImg
                    ? null
                    : Icon(Icons.person_outline,
                        color: AppTheme.navy, size: size * 0.5),
              ),
              if (!hasImg)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onAssignPhoto,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppTheme.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 12, color: AppTheme.cream),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 16,
          child: Text(
            personName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5.4: Ejecutar tests para confirmar que pasan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/features/milestones/presentation/widgets/person_avatar_badge_test.dart --reporter=expanded
```

Esperado: `+3: All tests passed!`

> **Nota:** El test `no muestra badge` comprueba que el badge desaparece cuando hay ruta. El widget internamente llama `File(path).existsSync()` que devuelve `false` para `/some/path.jpg` en tests (ruta no existe) — eso hace que `hasImg` sea `false` y el badge se mostraría. Si el test falla por esta razón, en el test reemplaza `faceImagePath: '/some/path.jpg'` por la ruta a un archivo temporal que sí exista creándolo con `Directory.systemTemp.createTempSync()`.
>
> Alternativa más robusta: extrae la lógica de `hasImg` a una función pura visible desde los tests y reemplaza la verificación de File en el constructor con un parámetro `hasPhoto` opcional para testing. Si optas por esta vía, añade el parámetro opcional `bool? hasPhoto` que sobreescribe el check de File cuando está presente.

- [ ] **Step 5.5: Commit**

```bash
git add lib/features/milestones/presentation/widgets/person_avatar_badge.dart test/features/milestones/presentation/widgets/person_avatar_badge_test.dart
git commit -m "feat(face-crop): add PersonAvatarBadge widget"
```

---

## Task 6: Widget — FaceSourceBottomSheet + Tests

**Files:**
- Create: `lib/features/milestones/presentation/widgets/face_source_bottom_sheet.dart`
- Create: `test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart`

- [ ] **Step 6.1: Escribir tests del widget (failing)**

Crear `test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/features/milestones/data/models/local/media_item_embed.dart';
import 'package:lifetime/domain/entities/media_item.dart';
import 'package:lifetime/features/milestones/presentation/widgets/face_source_bottom_sheet.dart';

MediaItemEmbed _makeImageItem(String path) {
  return MediaItemEmbed()
    ..localPath = path
    ..thumbnailPath = path
    ..mediaType = MediaType.image;
}

MediaItemEmbed _makeVideoItem(String path) {
  return MediaItemEmbed()
    ..localPath = path
    ..thumbnailPath = path
    ..mediaType = MediaType.video;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('siempre muestra botones Cámara y Galería', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () => showFaceSourceBottomSheet(context: ctx),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
  });

  testWidgets('muestra sección de hito cuando se pasan mediaItems con imágenes',
      (tester) async {
    final items = [_makeImageItem('/path/a.jpg'), _makeImageItem('/path/b.jpg')];

    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () =>
              showFaceSourceBottomSheet(context: ctx, milestoneMediaItems: items),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsOneWidget);
  });

  testWidgets('no muestra sección de hito cuando solo hay vídeos', (tester) async {
    final items = [_makeVideoItem('/path/v.mp4')];

    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () =>
              showFaceSourceBottomSheet(context: ctx, milestoneMediaItems: items),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsNothing);
  });

  testWidgets('no muestra sección de hito cuando milestoneMediaItems es null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () => showFaceSourceBottomSheet(context: ctx),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsNothing);
  });
}
```

- [ ] **Step 6.2: Ejecutar tests para confirmar que fallan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart 2>&1 | head -10
```

Esperado: error de compilación.

- [ ] **Step 6.3: Implementar FaceSourceBottomSheet**

Crear `lib/features/milestones/presentation/widgets/face_source_bottom_sheet.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../data/models/local/media_item_embed.dart';
import '../../../../domain/entities/media_item.dart';

class FaceSelection {
  final FaceImageSource source;
  final String? milestoneImagePath;

  const FaceSelection({required this.source, this.milestoneImagePath});
}

Future<FaceSelection?> showFaceSourceBottomSheet({
  required BuildContext context,
  List<MediaItemEmbed>? milestoneMediaItems,
}) {
  final imageItems = milestoneMediaItems
      ?.where((m) => m.mediaType == MediaType.image)
      .toList();
  final hasImages = imageItems != null && imageItems.isNotEmpty;

  return showModalBottomSheet<FaceSelection>(
    context: context,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _FaceSourceSheet(imageItems: hasImages ? imageItems : null),
  );
}

class _FaceSourceSheet extends StatelessWidget {
  final List<MediaItemEmbed>? imageItems;

  const _FaceSourceSheet({this.imageItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto de perfil', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Cámara',
                    onTap: () => Navigator.pop(
                      context,
                      const FaceSelection(source: FaceImageSource.camera),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galería',
                    onTap: () => Navigator.pop(
                      context,
                      const FaceSelection(source: FaceImageSource.gallery),
                    ),
                  ),
                ),
              ],
            ),
            if (imageItems != null) ...[
              const SizedBox(height: 20),
              Text('Imágenes del hito', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageItems!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = imageItems![i];
                    final file = File(item.localPath);
                    return GestureDetector(
                      onTap: () => Navigator.pop(
                        context,
                        FaceSelection(
                          source: FaceImageSource.milestoneImage,
                          milestoneImagePath: item.localPath,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: file.existsSync()
                            ? Image.file(file,
                                width: 72, height: 72, fit: BoxFit.cover)
                            : Container(
                                width: 72,
                                height: 72,
                                color: AppTheme.navy.withValues(alpha: 0.10),
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppTheme.navy),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.navy,
        side: const BorderSide(color: AppTheme.navy),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
```

- [ ] **Step 6.4: Ejecutar tests para confirmar que pasan**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart --reporter=expanded
```

Esperado: `+4: All tests passed!`

- [ ] **Step 6.5: Commit**

```bash
git add lib/features/milestones/presentation/widgets/face_source_bottom_sheet.dart test/features/milestones/presentation/widgets/face_source_bottom_sheet_test.dart
git commit -m "feat(face-crop): add FaceSourceBottomSheet widget"
```

---

## Task 7: Registrar FaceCropperService en injection_container

**Files:**
- Modify: `lib/injection_container.dart`

- [ ] **Step 7.1: Añadir imports**

En `lib/injection_container.dart`, añadir estos imports con los existentes:

```dart
import 'data/services/face_cropper_service_impl.dart';
import 'domain/services/face_cropper_service.dart';
```

- [ ] **Step 7.2: Registrar el servicio**

En `lib/injection_container.dart`, dentro del bloque `// ─── Services ─────────────────────────────────────────────────────────────`, añadir **después** del registro de `SpaceCleanupService`:

```dart
  sl.registerLazySingleton<FaceCropperService>(
    () => FaceCropperServiceImpl(personDs: sl<IsarPersonDataSource>()),
  );
```

- [ ] **Step 7.3: Verificar análisis**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/injection_container.dart
```

Esperado: `No issues found!`

- [ ] **Step 7.4: Commit**

```bash
git add lib/injection_container.dart
git commit -m "feat(face-crop): register FaceCropperService in DI container"
```

---

## Task 8: ManagePeoplePage — Tap Avatar → FaceSourceBottomSheet

**Files:**
- Modify: `lib/features/settings/presentation/pages/manage_people_page.dart`

- [ ] **Step 8.1: Añadir imports**

En `lib/features/settings/presentation/pages/manage_people_page.dart`, añadir:

```dart
import '../../../../domain/services/face_cropper_service.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
```

- [ ] **Step 8.2: Añadir referencia al servicio y método _assignPhoto**

En `_ManagePeoplePageState`, añadir el campo y el método:

```dart
  final _faceCropService = sl<FaceCropperService>();

  Future<void> _assignPhoto(PersonCollection p) async {
    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final cropResult = await _faceCropService.pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );

    if (!mounted) return;
    await cropResult.fold(
      (failure) async {
        if (failure is! FaceCropCancelledFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      (file) async {
        final saveResult = await _faceCropService.saveForPerson(
          personId: p.id,
          croppedFile: file,
        );
        if (!mounted) return;
        saveResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          ),
          (_) => setState(() {}),
        );
      },
    );
  }
```

- [ ] **Step 8.3: Envolver CircleAvatar en GestureDetector**

En el método `build` de `_ManagePeoplePageState`, localizar el `CircleAvatar` dentro de `ListTile.leading` y envolverlo con `GestureDetector`:

Reemplazar:
```dart
              leading: CircleAvatar(
                backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                backgroundImage: hasImg ? FileImage(File(img!)) : null,
                child: hasImg ? null : const Icon(Icons.person_outline, color: AppTheme.navy),
              ),
```

Con:
```dart
              leading: GestureDetector(
                onTap: () => _assignPhoto(p),
                child: CircleAvatar(
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                  backgroundImage: hasImg ? FileImage(File(img!)) : null,
                  child: hasImg ? null : const Icon(Icons.person_outline, color: AppTheme.navy),
                ),
              ),
```

- [ ] **Step 8.4: Añadir 'Asignar foto' al PopupMenuButton**

En el `PopupMenuButton`, añadir el item al inicio de la lista:

```dart
                    const PopupMenuItem(
                      value: 'assign_photo',
                      child: Text('Asignar foto de perfil'),
                    ),
```

Y en el `onSelected` handler, añadir:
```dart
                    if (value == 'assign_photo') await _assignPhoto(p);
```

- [ ] **Step 8.5: Verificar análisis**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/features/settings/presentation/pages/manage_people_page.dart
```

Esperado: `No issues found!`

- [ ] **Step 8.6: Commit**

```bash
git add lib/features/settings/presentation/pages/manage_people_page.dart
git commit -m "feat(face-crop): wire FaceCropperService into ManagePeoplePage"
```

---

## Task 9: AddMilestonePage — Sección de Participantes + PersonAvatarBadge

**Files:**
- Modify: `lib/features/milestones/presentation/pages/add_milestone_page.dart`

Esta tarea añade la sección de participantes al formulario de creación de hitos y conecta el `FaceCropperService` al badge `+` de cada persona.

- [ ] **Step 9.1: Añadir imports**

En `add_milestone_page.dart`, añadir:

```dart
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/person_collection.dart';
import '../widgets/face_source_bottom_sheet.dart';
import '../widgets/person_avatar_badge.dart';
import '../../../../core/failures/failure.dart';
```

> **Nota:** Algunos de estos imports pueden ya estar presentes. Omite los duplicados.

- [ ] **Step 9.2: Añadir estado de participantes y servicio a _CreateMilestoneViewState**

En `_CreateMilestoneViewState`, añadir los campos:

```dart
  final List<PersonCollection> _participants = [];
  final _faceCropService = sl<FaceCropperService>();
  final _personDs = sl<IsarPersonDataSource>();
```

- [ ] **Step 9.3: Añadir _addParticipant y _assignParticipantPhoto**

En `_CreateMilestoneViewState`, añadir los métodos:

```dart
  Future<void> _addParticipant() async {
    final all = await _personDs.fetchAll();
    final existing = {for (final p in _participants) p.id};
    final available = all.where((p) => !existing.contains(p.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay más personas disponibles.')),
      );
      return;
    }

    final picked = await showDialog<PersonCollection>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        backgroundColor: AppTheme.cream,
        title: const Text('Añadir persona'),
        children: available
            .map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogCtx, p),
                  child: Text(p.name),
                ))
            .toList(),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _participants.add(picked));
    }
  }

  Future<void> _assignParticipantPhoto(PersonCollection p) async {
    final imagePaths = _selectedMedia
        .where((m) => m.type == MediaType.image)
        .map((m) => m.file.path)
        .toList();

    final mediaItems = imagePaths
        .map((path) => MediaItemEmbed()
          ..localPath = path
          ..thumbnailPath = path
          ..mediaType = MediaType.image)
        .toList();

    if (!mounted) return;
    final selection = await showFaceSourceBottomSheet(
      context: context,
      milestoneMediaItems: mediaItems.isEmpty ? null : mediaItems,
    );
    if (selection == null || !mounted) return;

    final cropResult = await _faceCropService.pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );

    if (!mounted) return;
    await cropResult.fold(
      (failure) async {
        if (failure is! FaceCropCancelledFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      (file) async {
        final saveResult = await _faceCropService.saveForPerson(
          personId: p.id,
          croppedFile: file,
        );
        if (!mounted) return;
        saveResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          ),
          (updatedPerson) {
            setState(() {
              final idx = _participants.indexWhere((x) => x.id == p.id);
              if (idx != -1) {
                _participants[idx] = PersonCollection()
                  ..isarId = p.isarId
                  ..id = p.id
                  ..name = p.name
                  ..faceImagePath = updatedPerson.faceImagePath
                  ..driveFaceFileId = p.driveFaceFileId;
              }
            });
          },
        );
      },
    );
  }
```

- [ ] **Step 9.4: Pasar participantIds al submit**

En `_CreateMilestoneViewState._submit`, cambiar la llamada al cubit para incluir participantes:

```dart
    context.read<CreateMilestoneCubit>().submit(
          title: title.isEmpty ? null : title,
          userNote: note,
          eventDate: _selectedDate,
          categoryId: _categoryId,
          mediaFiles: _selectedMedia.map((e) => e.file).toList(),
          mediaTypes: _selectedMedia.map((e) => e.type).toList(),
          accessToken: accessToken,
          locationName: locationText.isEmpty ? null : locationText,
          latitude: _locationData?.latitude,
          longitude: _locationData?.longitude,
          participants: _participants.map((p) => p.id).toList(),
        );
```

- [ ] **Step 9.5: Añadir sección de participantes en el build**

En el `Column` del formulario de `_CreateMilestoneViewState`, añadir la sección de participantes **después** de `_MediaPickerSection` y **antes** de `_DatePickerRow`:

```dart
                            const SizedBox(height: 8),
                            _ParticipantsSection(
                              participants: _participants,
                              enabled: !isSubmitting,
                              onAdd: _addParticipant,
                              onAssignPhoto: _assignParticipantPhoto,
                              onRemove: (p) =>
                                  setState(() => _participants.remove(p)),
                            ),
```

- [ ] **Step 9.6: Añadir widget _ParticipantsSection**

Al final de `add_milestone_page.dart`, añadir:

```dart
class _ParticipantsSection extends StatelessWidget {
  final List<PersonCollection> participants;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<PersonCollection> onAssignPhoto;
  final ValueChanged<PersonCollection> onRemove;

  const _ParticipantsSection({
    required this.participants,
    required this.enabled,
    required this.onAdd,
    required this.onAssignPhoto,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: participants.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: participants.map((p) {
                    return GestureDetector(
                      onLongPress: enabled ? () => onRemove(p) : null,
                      child: PersonAvatarBadge(
                        faceImagePath: p.faceImagePath,
                        personName: p.name,
                        onAssignPhoto:
                            enabled ? () => onAssignPhoto(p) : () {},
                      ),
                    );
                  }).toList(),
                ),
        ),
        IconButton(
          onPressed: enabled ? onAdd : null,
          icon: const Icon(Icons.person_add_outlined),
          color: AppTheme.navy,
          tooltip: 'Añadir persona',
        ),
      ],
    );
  }
}
```

- [ ] **Step 9.7: Verificar análisis**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze lib/features/milestones/presentation/pages/add_milestone_page.dart
```

Esperado: `No issues found!`

- [ ] **Step 9.8: Ejecutar todos los tests**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test --reporter=expanded 2>&1 | tail -20
```

Esperado: todos los tests pasan.

- [ ] **Step 9.9: Commit final**

```bash
git add lib/features/milestones/presentation/pages/add_milestone_page.dart
git commit -m "feat(face-crop): add participants section to AddMilestonePage with PersonAvatarBadge"
```

---

## Verificación Final

- [ ] **Análisis global**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter analyze
```

Esperado: `No issues found!`

- [ ] **Suite completa de tests**

```bash
cd /mnt/c/Users/fernando/Proyectos/LifeTime && flutter test
```

Esperado: todos los tests en verde.
