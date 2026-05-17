import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Lee texto UTF-8 de un archivo elegido con [FilePicker].
///
/// En Android el plugin suele dejar el fichero en caché con [PlatformFile.path]
/// y [PlatformFile.bytes] vacío aunque `withData` sea true (archivos grandes).
Future<String?> readPickedFileAsUtf8Text(PlatformFile file) async {
  final inline = file.bytes;
  if (inline != null && inline.isNotEmpty) {
    return utf8.decode(inline);
  }

  final path = file.path?.trim();
  if (kIsWeb || path == null || path.isEmpty) return null;

  final ioFile = File(path);
  if (!await ioFile.exists()) return null;
  return ioFile.readAsString(encoding: utf8);
}
