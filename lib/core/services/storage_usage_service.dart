import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Desglose del almacenamiento que consume la app en el dispositivo.
class StorageUsage {
  const StorageUsage({
    required this.imageBytes,
    required this.videoBytes,
    required this.dataBytes,
    required this.imageCount,
    required this.videoCount,
    required this.otherCount,
  });

  final int imageBytes;
  final int videoBytes;
  final int dataBytes;
  final int imageCount;
  final int videoCount;
  final int otherCount;

  int get totalBytes => imageBytes + videoBytes + dataBytes;

  static const empty = StorageUsage(
    imageBytes: 0,
    videoBytes: 0,
    dataBytes: 0,
    imageCount: 0,
    videoCount: 0,
    otherCount: 0,
  );
}

/// Calcula el espacio usado por la app escaneando sus carpetas de datos.
class StorageUsageService {
  static const _channel = MethodChannel('lifetime/media_scanner');

  static const _imageExts = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif', '.bmp',
  };
  static const _videoExts = {
    '.mp4', '.mov', '.m4v', '.3gp', '.avi', '.mkv', '.webm',
  };

  Future<StorageUsage> compute() async {
    final roots = await _roots();
    final seen = <String>{};

    var imageBytes = 0;
    var videoBytes = 0;
    var dataBytes = 0;
    var imageCount = 0;
    var videoCount = 0;
    var otherCount = 0;

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          if (!seen.add(entity.path)) continue;
          int size;
          try {
            size = await entity.length();
          } catch (_) {
            continue;
          }
          final ext = p.extension(entity.path).toLowerCase();
          if (_imageExts.contains(ext)) {
            imageBytes += size;
            imageCount++;
          } else if (_videoExts.contains(ext)) {
            videoBytes += size;
            videoCount++;
          } else {
            dataBytes += size;
            otherCount++;
          }
        }
      } catch (_) {
        // Carpeta inaccesible: se ignora.
      }
    }

    return StorageUsage(
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      dataBytes: dataBytes,
      imageCount: imageCount,
      videoCount: videoCount,
      otherCount: otherCount,
    );
  }

  /// Carpetas raíz a escanear (sin solapamientos), incluyendo la raíz de
  /// medios externa de Android cuando aplica.
  Future<List<String>> _roots() async {
    final candidates = <String>[];

    final docs = await getApplicationDocumentsDirectory();
    candidates.add(docs.path);
    try {
      final support = await getApplicationSupportDirectory();
      candidates.add(support.path);
    } catch (_) {
      // No disponible en alguna plataforma.
    }
    if (Platform.isAndroid) {
      try {
        final mediaRoot = await _channel.invokeMethod<String>('getMediaRoot');
        if (mediaRoot != null && mediaRoot.trim().isNotEmpty) {
          candidates.add(mediaRoot.trim());
        }
      } catch (_) {
        // Sin canal nativo: los medios estarán bajo app-docs/media.
      }
    }

    // Elimina rutas anidadas para no contar dos veces.
    final unique = <String>[];
    bool isunder(String child, String parent) =>
        child == parent ||
        child.startsWith('$parent${Platform.pathSeparator}') ||
        child.startsWith('$parent/');
    for (final c in candidates) {
      if (unique.any((u) => isunder(c, u))) continue;
      unique.removeWhere((u) => isunder(u, c));
      unique.add(c);
    }
    return unique;
  }
}

/// Formatea bytes a una cadena legible (coma decimal, estilo es-ES).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final text = value.toStringAsFixed(value >= 100 ? 0 : 1);
  return '${text.replaceAll('.', ',')} ${units[i]}';
}
