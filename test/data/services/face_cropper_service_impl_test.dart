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
          expect(person.driveFaceFileId, isNull);
        },
      );

      final destPath = '${tempDir.path}/faces/p1.jpg';
      expect(File(destPath).existsSync(), isTrue);
    });

    test('returns Left(FaceCropSaveFailure) when person not found', () async {
      final croppedFile = File('${tempDir.path}/crop.jpg')..writeAsBytesSync([1]);
      when(() => personDs.fetchById('unknown')).thenAnswer((_) async => null);

      final result =
          await sut.saveForPerson(personId: 'unknown', croppedFile: croppedFile);

      expect(result.fold((f) => f, (_) => null), isA<FaceCropSaveFailure>());
    });
  });
}
