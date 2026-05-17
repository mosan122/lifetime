import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/core/utils/picked_file_utf8_text.dart';

void main() {
  test('lee desde path cuando bytes es null (Android file_picker)', () async {
    final dir = await Directory.systemTemp.createTemp('lifetime_import_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final file = File('${dir.path}/backup.json');
    await file.writeAsString(
      jsonEncode({
        'app': 'LifeTime',
        'milestones': [
          {'id': 'ms-1', 'title': 'Test'},
        ],
      }),
      encoding: utf8,
    );

    final text = await readPickedFileAsUtf8Text(
      PlatformFile(name: 'backup.json', size: 0, path: file.path),
    );

    expect(text, isNotNull);
    expect(text, contains('"milestones"'));
  });

  test('prefiere bytes inline cuando están disponibles', () async {
    const payload = '{"milestones":[]}';
    final text = await readPickedFileAsUtf8Text(
      PlatformFile(
        name: 'x.json',
        size: payload.length,
        bytes: utf8.encode(payload),
      ),
    );
    expect(text, payload);
  });
}
