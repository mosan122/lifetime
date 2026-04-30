import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';

import '../../../../core/failures/failure.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/get_media_thumbnail_usecase.dart';

// ── URL cache ─────────────────────────────────────────────────────────────────
// Module-level map: survives widget disposal/recreation (scroll off and back).
// Keyed by fileId → thumbnailLink URL. One Drive API call per fileId per session.
final _urlCache = <String, String>{};

/// Displays a Drive thumbnail with two levels of caching:
///
/// 1. **URL resolution**: the Drive API call (`files.get?fields=thumbnailLink`)
///    is made at most once per fileId per session. The resolved URL is stored
///    in [_urlCache] and reused on every subsequent widget creation.
///
/// 2. **Image bytes**: [CachedNetworkImage] stores the decoded image in memory
///    and on disk. The cache key is `drive_<fileId>` — stable even if Drive
///    regenerates its short-lived thumbnail URL — so the download is skipped
///    on subsequent scrolls and across app restarts.
///
/// Auth headers are injected only on the initial network fetch; cache hits
/// bypass the network entirely.
class DriveThumbnail extends StatefulWidget {
  final String fileId;
  final String accessToken;

  const DriveThumbnail({
    required this.fileId,
    required this.accessToken,
    super.key,
  });

  @override
  State<DriveThumbnail> createState() => _DriveThumbnailState();
}

class _DriveThumbnailState extends State<DriveThumbnail> {
  late Future<Either<Failure, String>> _future;

  @override
  void initState() {
    super.initState();

    final cached = _urlCache[widget.fileId];
    if (cached != null) {
      // URL already known — skip the Drive API call entirely.
      _future = Future.value(Right(cached));
    } else {
      _future = sl<GetMediaThumbnailUseCase>()(
        GetMediaThumbnailParams(
          fileId: widget.fileId,
          accessToken: widget.accessToken,
        ),
      ).then((result) {
        // Persist URL so the next widget creation for the same fileId is free.
        result.fold((_) {}, (url) => _urlCache[widget.fileId] = url);
        return result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, String>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _ThumbnailShimmer();

        return snapshot.data!.fold(
          (_) => const _ThumbnailError(),
          (url) => CachedNetworkImage(
            imageUrl: url,
            // Stable key: uses fileId, not the short-lived Drive URL.
            // This means the cached bytes survive URL regeneration.
            cacheKey: 'drive_${widget.fileId}',
            httpHeaders: {'Authorization': 'Bearer ${widget.accessToken}'},
            fit: BoxFit.cover,
            placeholder: (_, __) => const _ThumbnailShimmer(),
            errorWidget: (_, __, ___) => const _ThumbnailError(),
          ),
        );
      },
    );
  }
}

// ── Placeholder & error ───────────────────────────────────────────────────────

class _ThumbnailShimmer extends StatelessWidget {
  const _ThumbnailShimmer();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFE8E8D0));
}

class _ThumbnailError extends StatelessWidget {
  const _ThumbnailError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFEDEDD4),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Color(0xFFAAAAAA), size: 32),
        ),
      );
}
