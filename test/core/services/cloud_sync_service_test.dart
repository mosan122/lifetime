import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:lifetime/core/services/cloud_sync_service.dart';
import 'package:lifetime/core/services/google_drive_service.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/data/datasources/isar_milestone_datasource.dart';
import 'package:lifetime/features/milestones/data/datasources/isar_person_datasource.dart';
import 'package:lifetime/features/milestones/data/models/local/person_collection.dart';

class MockGoogleDriveService extends Mock implements GoogleDriveService {}
class MockIsarPersonDataSource extends Mock implements IsarPersonDataSource {}
class MockPremiumService extends Mock implements PremiumService {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockIsarMilestoneDataSource extends Mock implements IsarMilestoneDataSource {}

class _FakePath extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePath(this._path);
  final String _path;
  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

PersonCollection _makePerson({
  required String id,
  String? faceImagePath,
  String? driveFaceFileId,
}) {
  return PersonCollection()
    ..isarId = 1
    ..id = id
    ..name = 'Test'
    ..faceImagePath = faceImagePath
    ..driveFaceFileId = driveFaceFileId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleDriveService driveService;
  late MockIsarPersonDataSource personDs;
  late CloudSyncService sut;
  late Directory tempDir;

  setUp(() async {
    driveService = MockGoogleDriveService();
    personDs = MockIsarPersonDataSource();
    tempDir = await Directory.systemTemp.createTemp('cloud_sync_test_');
    PathProviderPlatform.instance = _FakePath(tempDir.path);

    // GoogleSignIn and IsarMilestoneDataSource are not called by the
    // @visibleForTesting methods under test — mocks are passed but never invoked.
    sut = CloudSyncService(
      MockPremiumService(),
      MockGoogleSignIn(),
      MockIsarMilestoneDataSource(),
      personDs,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('syncPendingFaces', () {
    test('uploads face and updates driveFaceFileId when pending', () async {
      final faceFile = File('${tempDir.path}/faces/p1.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      final person = _makePerson(
        id: 'p1',
        faceImagePath: faceFile.path,
        driveFaceFileId: null,
      );

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);
      when(() => driveService.getOrCreateFolder('System', parentId: 'root'))
          .thenAnswer((_) async => 'sys_id');
      when(() => driveService.getOrCreateFolder('People', parentId: 'sys_id'))
          .thenAnswer((_) async => 'people_id');
      when(() => driveService.uploadFile(any(), 'people_id'))
          .thenAnswer((_) async => 'drive_face_id');
      when(() => personDs.upsert(any())).thenAnswer((inv) async =>
          inv.positionalArguments.first as PersonCollection);

      await sut.syncPendingFaces(driveService, 'root');

      final captured = verify(() => personDs.upsert(captureAny())).captured;
      final saved = captured.first as PersonCollection;
      expect(saved.driveFaceFileId, equals('drive_face_id'));
    });

    test('skips person with driveFaceFileId already set', () async {
      final person = _makePerson(
        id: 'p1',
        faceImagePath: '/some/path.jpg',
        driveFaceFileId: 'already_synced',
      );

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);
      when(() => driveService.getOrCreateFolder(any(), parentId: any(named: 'parentId')))
          .thenAnswer((_) async => 'folder_id');

      await sut.syncPendingFaces(driveService, 'root');

      verifyNever(() => driveService.uploadFile(any(), any()));
    });

    test('skips person with null faceImagePath', () async {
      final person = _makePerson(id: 'p1', faceImagePath: null, driveFaceFileId: null);

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);
      when(() => driveService.getOrCreateFolder(any(), parentId: any(named: 'parentId')))
          .thenAnswer((_) async => 'folder_id');

      await sut.syncPendingFaces(driveService, 'root');

      verifyNever(() => driveService.uploadFile(any(), any()));
    });

    test('skips person when local file does not exist', () async {
      final person = _makePerson(
        id: 'p1',
        faceImagePath: '/nonexistent/path.jpg',
        driveFaceFileId: null,
      );

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);
      when(() => driveService.getOrCreateFolder(any(), parentId: any(named: 'parentId')))
          .thenAnswer((_) async => 'folder_id');

      await sut.syncPendingFaces(driveService, 'root');

      verifyNever(() => driveService.uploadFile(any(), any()));
    });

    test('continues loop if one upload fails', () async {
      // Creates two real files; uploadFile throws on first call, succeeds on second.
      // Uses any() because dart:io File does not implement == by path.
      File('${tempDir.path}/faces/p1.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      File('${tempDir.path}/faces/p2.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([2]);

      final p1 = _makePerson(
          id: 'p1',
          faceImagePath: '${tempDir.path}/faces/p1.jpg',
          driveFaceFileId: null);
      final p2 = _makePerson(
          id: 'p2',
          faceImagePath: '${tempDir.path}/faces/p2.jpg',
          driveFaceFileId: null);

      when(() => personDs.fetchAll()).thenAnswer((_) async => [p1, p2]);
      when(() => driveService.getOrCreateFolder(any(), parentId: any(named: 'parentId')))
          .thenAnswer((_) async => 'folder_id');

      var uploadCount = 0;
      when(() => driveService.uploadFile(any(), any())).thenAnswer((_) async {
        uploadCount++;
        if (uploadCount == 1) throw Exception('network error');
        return 'drive_p2_id';
      });
      when(() => personDs.upsert(any())).thenAnswer((inv) async =>
          inv.positionalArguments.first as PersonCollection);

      await sut.syncPendingFaces(driveService, 'root');

      final captured = verify(() => personDs.upsert(captureAny())).captured;
      expect(captured.length, 1);
      expect((captured.first as PersonCollection).id, 'p2');
    });
  });

  group('restoreFacesWithService', () {
    test('downloads face and updates faceImagePath when file missing', () async {
      final person = _makePerson(
        id: 'p1',
        faceImagePath: '/nonexistent/path.jpg',
        driveFaceFileId: 'drive_id_123',
      );

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);
      when(() => driveService.downloadFile(any(), any()))
          .thenAnswer((_) async {});
      when(() => personDs.upsert(any())).thenAnswer((inv) async =>
          inv.positionalArguments.first as PersonCollection);

      await sut.restoreFacesWithService(driveService);

      final captured = verify(() => personDs.upsert(captureAny())).captured;
      final saved = captured.first as PersonCollection;
      expect(saved.faceImagePath, contains('p1.jpg'));
      expect(saved.driveFaceFileId, equals('drive_id_123'));
    });

    test('skips person with null driveFaceFileId', () async {
      final person = _makePerson(id: 'p1', faceImagePath: null, driveFaceFileId: null);

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);

      await sut.restoreFacesWithService(driveService);

      verifyNever(() => driveService.downloadFile(any(), any()));
    });

    test('skips person whose local file already exists', () async {
      final existingFile = File('${tempDir.path}/faces/p1.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);

      final person = _makePerson(
        id: 'p1',
        faceImagePath: existingFile.path,
        driveFaceFileId: 'drive_id_123',
      );

      when(() => personDs.fetchAll()).thenAnswer((_) async => [person]);

      await sut.restoreFacesWithService(driveService);

      verifyNever(() => driveService.downloadFile(any(), any()));
    });

    test('continues loop if one download fails', () async {
      final p1 = _makePerson(id: 'p1', faceImagePath: null, driveFaceFileId: 'id1');
      final p2 = _makePerson(id: 'p2', faceImagePath: null, driveFaceFileId: 'id2');

      when(() => personDs.fetchAll()).thenAnswer((_) async => [p1, p2]);
      when(() => driveService.downloadFile('id1', any()))
          .thenThrow(Exception('not found'));
      when(() => driveService.downloadFile('id2', any()))
          .thenAnswer((_) async {});
      when(() => personDs.upsert(any())).thenAnswer((inv) async =>
          inv.positionalArguments.first as PersonCollection);

      await sut.restoreFacesWithService(driveService);

      final captured = verify(() => personDs.upsert(captureAny())).captured;
      expect(captured.length, 1);
      expect((captured.first as PersonCollection).id, 'p2');
    });
  });

  group('deleteFaceFromDriveWithService', () {
    test('calls deleteById with the given fileId', () async {
      when(() => driveService.deleteById('drive_id_abc'))
          .thenAnswer((_) async {});

      await sut.deleteFaceFromDriveWithService(driveService, 'drive_id_abc');

      verify(() => driveService.deleteById('drive_id_abc')).called(1);
    });

    test('propagates exceptions to caller (outer catch in deleteDriveFace handles them)', () async {
      when(() => driveService.deleteById(any()))
          .thenThrow(Exception('not found'));

      expect(
        () => sut.deleteFaceFromDriveWithService(driveService, 'bad_id'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
