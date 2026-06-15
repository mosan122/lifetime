import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/core/services/local_media_store_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this._documentsPath);

  final String _documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;

  setUp(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPlatform;
  });

  test('deleteFolder no lanza excepción cuando la carpeta no existe', () async {
    final tempRoot = await Directory.systemTemp.createTemp('lifetime_test_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot.path);
    final store = LocalMediaStoreImpl();

    await expectLater(
      () => store.deleteFolder(DateTime(2026, 4, 26), 'ms-missing'),
      returnsNormally,
    );
  });
}
