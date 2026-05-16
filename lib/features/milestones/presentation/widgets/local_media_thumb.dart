import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/services/google_drive_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../injection_container.dart';

bool _isRasterImageFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}

/// Miniatura local para imagen o vídeo (descarga imagen desde Drive si falta;
/// para vídeo genera JPEG con [VideoThumbnail] si no hay miniatura raster).
class LocalMediaThumb extends StatefulWidget {
  final MediaItem item;
  final BoxFit fit;
  /// Si no es null, sustituye el color del icono cuando falla la miniatura.
  final Color? placeholderIconColor;

  const LocalMediaThumb({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.placeholderIconColor,
  });

  @override
  State<LocalMediaThumb> createState() => _LocalMediaThumbState();
}

class _LocalMediaThumbState extends State<LocalMediaThumb> {
  Uint8List? _videoBytes;
  var _videoGenStarted = false;
  var _downloading = false;

  @override
  void initState() {
    super.initState();
    _maybeDownloadImageFromDrive();
    _maybeGenerateVideoThumb();
  }

  @override
  void didUpdateWidget(covariant LocalMediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.localPath != widget.item.localPath ||
        oldWidget.item.thumbnailPath != widget.item.thumbnailPath ||
        oldWidget.item.mediaType != widget.item.mediaType ||
        oldWidget.item.driveFileId != widget.item.driveFileId) {
      _videoBytes = null;
      _videoGenStarted = false;
      _maybeDownloadImageFromDrive();
      _maybeGenerateVideoThumb();
    }
  }

  Future<void> _maybeDownloadImageFromDrive() async {
    final item = widget.item;
    if (item.mediaType != MediaType.image) return;

    final path = item.localPath;
    final driveId = item.driveFileId;
    if (driveId == null || driveId.trim().isEmpty) return;
    if (path.trim().isEmpty) return;
    if (File(path).existsSync()) return;
    if (_downloading) return;

    setState(() => _downloading = true);
    try {
      final googleSignIn = sl<GoogleSignIn>();
      final service = GoogleDriveService(googleSignIn);
      await service.downloadFile(driveId, path);
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _maybeGenerateVideoThumb() {
    if (widget.item.mediaType != MediaType.video) return;
    if (_videoGenStarted) return;
    final thumb = widget.item.thumbnailPath.trim();
    if (thumb.isNotEmpty &&
        File(thumb).existsSync() &&
        _isRasterImageFile(thumb)) {
      return;
    }
    final videoPath = widget.item.localPath.trim();
    if (videoPath.isEmpty || !File(videoPath).existsSync()) return;

    _videoGenStarted = true;
    VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      quality: 70,
      maxWidth: 720,
      timeMs: 0,
    ).then((bytes) {
      if (!mounted || bytes == null || bytes.isEmpty) return;
      setState(() => _videoBytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    if (item.mediaType == MediaType.image) {
      final path = item.localPath;
      if (!File(path).existsSync() && item.driveFileId != null) {
        return ColoredBox(
          color: Colors.black12,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_download_outlined,
                  size: 36,
                  color: AppTheme.navy.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 8),
                Text(
                  _downloading ? 'Descargando de la nube…' : 'Preparando…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.navy.withValues(alpha: 0.55),
                      ),
                ),
              ],
            ),
          ),
        );
      }

      if (!File(path).existsSync()) {
        return _broken(isVideo: false);
      }

      return Image.file(
        File(path),
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _broken(isVideo: false),
      );
    }

    if (_videoBytes != null) {
      return Image.memory(
        _videoBytes!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _broken(isVideo: true),
      );
    }

    final thumb = item.thumbnailPath.trim();
    if (thumb.isNotEmpty &&
        File(thumb).existsSync() &&
        _isRasterImageFile(thumb)) {
      return Image.file(
        File(thumb),
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _broken(isVideo: true),
      );
    }

    return _broken(isVideo: true);
  }

  Widget _broken({required bool isVideo}) {
    final iconColor = widget.placeholderIconColor ??
        AppTheme.navy.withValues(alpha: 0.35);
    return ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_outlined : Icons.image_outlined,
          size: 40,
          color: iconColor,
        ),
      ),
    );
  }
}
