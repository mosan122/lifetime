import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../data/datasources/isar_category_datasource.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../bloc/delete_milestone_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import '../widgets/local_media_thumb.dart';
import 'add_milestone_page.dart';
import '../../data/models/local/person_collection.dart';

/// Galería en el cuerpo (tras Personas): hasta 30 celdas; la última puede ser +X.
const int _kBodyGalleryMaxCells = 30;
const int _kBodyGalleryCrossAxisCount = 3;

int milestoneClampedGalleryCoverIndex(Milestone m) {
  final n = m.mediaItems.length;
  if (n <= 0) return 0;
  return m.galleryCoverIndex.clamp(0, n - 1);
}

double _detailAppBarExpandedHeight({
  required bool hasMediaItems,
  required bool hasDriveHeaderImage,
}) {
  if (hasMediaItems) return 208;
  if (hasDriveHeaderImage) return 300;
  return 180;
}

Future<void> _openMilestoneMediaGallery(
  BuildContext context, {
  required String milestoneId,
  required List<MediaItem> items,
  required int initialIndex,
  required int galleryCoverIndex,
}) async {
  if (items.isEmpty) return;
  final i = initialIndex.clamp(0, items.length - 1);
  final cover = galleryCoverIndex.clamp(0, items.length - 1);
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogCtx) => _MediaGalleryDialog(
      milestoneId: milestoneId,
      items: items,
      initialIndex: i,
      coverIndex: cover,
    ),
  );
}

class MilestoneDetailPage extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;
  final VoidCallback? onLocalMilestoneChanged;

  const MilestoneDetailPage({
    super.key,
    required this.milestone,
    this.accessToken,
    this.onLocalMilestoneChanged,
  });

  /// Stable Hero tag shared between source card and this page.
  static String heroTag(String milestoneId) => 'milestone-image-$milestoneId';

  /// Hero para el índice [index]; coincide con [heroTag] cuando es la portada del timeline.
  static String heroMediaTag(
    String milestoneId,
    int index,
    int galleryCoverIndex,
  ) =>
      index == galleryCoverIndex
          ? heroTag(milestoneId)
          : 'milestone-image-$milestoneId-$index';

  /// Plain-text share summary. Static so it can be unit-tested without
  /// constructing the widget.
  static String formatForSharing(Milestone milestone) {
    final d = milestone.eventDate;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    final buf = StringBuffer()
      ..writeln('📖 ${milestone.title}')
      ..writeln('📅 $date');

    if (milestone.locationName != null) {
      buf.writeln('📍 ${milestone.locationName}');
    }
    buf.writeln();

    if (milestone.description != null && milestone.description!.isNotEmpty) {
      buf
        ..writeln(milestone.description!)
        ..writeln();
    }

    buf.write('— Guardado en LifeTime');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DeleteMilestoneCubit>(),
      child: _DetailScaffold(
        initialMilestone: milestone,
        accessToken: accessToken,
        onLocalMilestoneChanged: onLocalMilestoneChanged,
      ),
    );
  }
}

// ── Scaffold with delete listener ────────────────────────────────────────────

class _DetailScaffold extends StatefulWidget {
  final Milestone initialMilestone;
  final String? accessToken;
  final VoidCallback? onLocalMilestoneChanged;

  const _DetailScaffold({
    required this.initialMilestone,
    this.accessToken,
    this.onLocalMilestoneChanged,
  });

  @override
  State<_DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends State<_DetailScaffold> {
  late Milestone _milestone;

  @override
  void initState() {
    super.initState();
    _milestone = widget.initialMilestone;
  }

  @override
  void didUpdateWidget(covariant _DetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMilestone.id != widget.initialMilestone.id) {
      _milestone = widget.initialMilestone;
    }
  }

  bool get _hasDriveHeaderImage =>
      _milestone.driveFileId != null && widget.accessToken != null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeleteMilestoneCubit, DeleteMilestoneState>(
      listener: (context, state) {
        if (state is DeleteMilestoneSuccess) {
          Navigator.pop(context, 'deleted');
        }
        if (state is DeleteMilestoneError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final isOwner = currentUserId == _milestone.userId;
    final isDeleting =
        context.watch<DeleteMilestoneCubit>().state is DeleteMilestoneDeleting;

    final hasMediaItems = _milestone.mediaItems.isNotEmpty;
    final expandedHeight = _detailAppBarExpandedHeight(
      hasMediaItems: hasMediaItems,
      hasDriveHeaderImage: _hasDriveHeaderImage,
    );

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.navy,
      automaticallyImplyLeading: false,
      leading: _CircleButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'Editar',
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: isDeleting
              ? null
              : () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMilestonePage(initial: _milestone),
                    ),
                  );
                  if (result == true && context.mounted) {
                    Navigator.pop(context, 'edited');
                  }
                },
        ),
        if (isOwner) ...[
          _CircleButton(
            icon: Icons.delete_outline,
            onPressed: isDeleting
                ? () {}
                : () => _confirmDelete(context),
          ),
        ],
        _CircleButton(
          icon: Icons.share_outlined,
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: MilestoneDetailPage.formatForSharing(_milestone),
              subject: _milestone.title,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: hasMediaItems
            ? _FirstLocalMediaHeader(milestone: _milestone)
            : _hasDriveHeaderImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: MilestoneDetailPage.heroTag(_milestone.id),
                        child: DriveThumbnail(
                          fileId: _milestone.driveFileId!,
                          accessToken: widget.accessToken!,
                        ),
                      ),
                      const _GradientScrim(),
                    ],
                  )
                : const _NoImageHeader(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<DeleteMilestoneCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cream,
        title: const Text('Borrar hito'),
        content: const Text(
          '¿Seguro? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Borrar',
              style: TextStyle(
                color: Theme.of(dialogCtx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      cubit.delete(_milestone.id, accessToken: widget.accessToken);
    }
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final d = _milestone.eventDate;
    final formatted =
        '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
    final title = _milestone.title.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryChip(categoryId: _milestone.categoryId),
              const Spacer(),
              Text(formatted, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          if (title.isNotEmpty)
            Text(
              title,
              style: theme.textTheme.headlineLarge,
            ),
          if (_milestone.locationName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _milestone.locationName!,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _Narrative(description: _milestone.description),
          const SizedBox(height: 18),
          _SemanticChips(milestone: _milestone),
        ],
      ),
    );
  }
}

// ── Narrative with editorial drop cap ────────────────────────────────────────

class _Narrative extends StatelessWidget {
  final String? description;
  const _Narrative({required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (description == null || description!.isEmpty) {
      return Text(
        'Sin relato guardado.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFFAAAAAA), fontStyle: FontStyle.italic),
      );
    }

    final text = description!;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text[0],
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          ..._highlightedSpans(
            theme: theme,
            text: text.substring(1),
          ),
        ],
      ),
    );
  }

  static List<InlineSpan> _highlightedSpans({
    required ThemeData theme,
    required String text,
  }) {
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.85);
    final accent = base?.copyWith(
      color: AppTheme.navy,
      fontWeight: FontWeight.w700,
    );

    final exp = RegExp(r'(@[A-Za-z0-9_]+|#[A-Za-z0-9_]+)');
    final matches = exp.allMatches(text).toList();
    if (matches.isEmpty) {
      return [
        TextSpan(text: text, style: base),
      ];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
      }
      spans.add(TextSpan(text: text.substring(m.start, m.end), style: accent));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return spans;
  }
}

// ── Semantic chips ────────────────────────────────────────────────────────────

class _SemanticChips extends StatelessWidget {
  final Milestone milestone;

  const _SemanticChips({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participantIds = milestone.participantIds;
    final tags = milestone.tags;
    final mediaItems = milestone.mediaItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (participantIds.isNotEmpty) ...[
          Text('Personas', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _PeopleFacesRow(participantIds: participantIds),
          const SizedBox(height: 16),
        ],
        if (mediaItems.isNotEmpty) ...[
          _BodyMediaGallery(milestone: milestone),
          const SizedBox(height: 16),
        ],
        if (tags.isNotEmpty) ...[
          Text('Tags', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: tags.map((t) => _Chip(label: '#$t')).toList(),
          ),
        ],
      ],
    );
  }
}

class _PeopleFacesRow extends StatelessWidget {
  final List<String> participantIds;
  const _PeopleFacesRow({required this.participantIds});

  @override
  Widget build(BuildContext context) {
    final ds = sl<IsarPersonDataSource>();
    return FutureBuilder(
      future: ds.fetchByIds(participantIds),
      builder: (context, snapshot) {
        final people = snapshot.data ?? const <PersonCollection>[];
        if (people.isEmpty) return const SizedBox.shrink();

        final byId = {for (final p in people) p.id: p};
        final ordered = participantIds.map((id) => byId[id]).whereType<PersonCollection>().toList();

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: ordered.map((p) {
            final img = p.faceImagePath;
            final hasImg = img != null && img.trim().isNotEmpty && File(img).existsSync();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                  backgroundImage: hasImg ? FileImage(File(img)) : null,
                  child: hasImg ? null : const Icon(Icons.person_outline, size: 18, color: AppTheme.navy),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

// ── App-bar supporting widgets ────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _GradientScrim extends StatelessWidget {
  const _GradientScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black45],
          stops: [0.45, 1.0],
        ),
      ),
    );
  }
}

// ── Primer medio en el app bar (Hero) + galería en el cuerpo ─────────────────

class _FirstLocalMediaHeader extends StatelessWidget {
  final Milestone milestone;
  const _FirstLocalMediaHeader({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final items = milestone.mediaItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final coverIdx = milestoneClampedGalleryCoverIndex(milestone);
    final cover = items[coverIdx];
    return SafeArea(
      bottom: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: MilestoneDetailPage.heroTag(milestone.id),
            child: LocalMediaThumb(item: cover, fit: BoxFit.cover),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: _GradientScrim()),
          ),
        ],
      ),
    );
  }
}

class _BodyMediaGallery extends StatelessWidget {
  final Milestone milestone;

  const _BodyMediaGallery({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final items = milestone.mediaItems;
    final milestoneId = milestone.id;
    final coverIdx = milestoneClampedGalleryCoverIndex(milestone);
    final n = items.length;
    final hasOverflow = n > _kBodyGalleryMaxCells;
    final itemCount = hasOverflow ? _kBodyGalleryMaxCells : n;
    final extraShown = hasOverflow ? n - (_kBodyGalleryMaxCells - 1) : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kBodyGalleryCrossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (hasOverflow && i == itemCount - 1) {
                return _OverflowMediaGridTile(
                  extraCount: extraShown,
                  onTap: () => _openMilestoneMediaGallery(
                    context,
                    milestoneId: milestoneId,
                    items: items,
                    initialIndex: _kBodyGalleryMaxCells - 1,
                    galleryCoverIndex: coverIdx,
                  ),
                );
              }
              return _MediaGridTile(
                milestoneId: milestoneId,
                items: items,
                index: i,
                galleryCoverIndex: coverIdx,
                isTimelineCover: i == coverIdx,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MediaGridTile extends StatelessWidget {
  final String milestoneId;
  final List<MediaItem> items;
  final int index;
  final int galleryCoverIndex;
  final bool isTimelineCover;

  const _MediaGridTile({
    required this.milestoneId,
    required this.items,
    required this.index,
    required this.galleryCoverIndex,
    required this.isTimelineCover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = items[index];
    final heroTag = MilestoneDetailPage.heroMediaTag(
      milestoneId,
      index,
      galleryCoverIndex,
    );
    final isVideo = item.mediaType == MediaType.video;

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: isTimelineCover
                ? LocalMediaThumb(item: item)
                : Hero(
                    tag: heroTag,
                    child: LocalMediaThumb(item: item),
                  ),
          ),
          if (isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          if (isTimelineCover)
            Positioned(
              left: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.navy.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    'Timeline',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.cream,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () => _openMilestoneMediaGallery(
          context,
          milestoneId: milestoneId,
          items: items,
          initialIndex: index,
          galleryCoverIndex: galleryCoverIndex,
        ),
        child: preview,
      ),
    );
  }
}

class _OverflowMediaGridTile extends StatelessWidget {
  final int extraCount;
  final VoidCallback onTap;

  const _OverflowMediaGridTile({
    required this.extraCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade800,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Ver $extraCount elementos más en galería',
          child: Center(
            child: Text(
              '+$extraCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaGalleryDialog extends StatelessWidget {
  final String milestoneId;
  final List<MediaItem> items;
  final int initialIndex;
  final int coverIndex;

  const _MediaGalleryDialog({
    required this.milestoneId,
    required this.items,
    required this.initialIndex,
    required this.coverIndex,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialIndex);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: controller,
            itemCount: items.length,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, i) {
              final it = items[i];
              final heroTag =
                  MilestoneDetailPage.heroMediaTag(milestoneId, i, coverIndex);

              if (it.mediaType == MediaType.video) {
                return PhotoViewGalleryPageOptions.customChild(
                  heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                  child: _VideoGalleryPage(
                    item: it,
                    onPlay: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _VideoPlayerPage(videoPath: it.localPath),
                      ),
                    ),
                  ),
                );
              }

              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(it.localPath)),
                heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
          ),
          Positioned(
            top: 14,
            left: 12,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cerrar',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoGalleryPage extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onPlay;

  const _VideoGalleryPage({
    required this.item,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: LocalMediaThumb(
            item: item,
            fit: BoxFit.contain,
            placeholderIconColor: Colors.white38,
          ),
        ),
        Center(
          child: IconButton(
            onPressed: onPlay,
            iconSize: 76,
            color: Colors.white70,
            icon: const Icon(Icons.play_circle_fill),
            tooltip: 'Reproducir',
          ),
        ),
      ],
    );
  }
}

// ── Video player ──────────────────────────────────────────────────────────────

class _VideoPlayerPage extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerPage({required this.videoPath});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowPlaybackSpeedChanging: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.navy,
          handleColor: AppTheme.navy,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
      );

      if (!mounted) {
        await controller.dispose();
        chewie.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _chewieController = chewie;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewieController;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vídeo'),
      ),
      body: Center(
        child: _initError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo reproducir el vídeo.\n\n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : chewie == null
                ? const CircularProgressIndicator(color: Colors.white70)
                : Chewie(controller: chewie),
      ),
    );
  }
}

class _NoImageHeader extends StatelessWidget {
  const _NoImageHeader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.navy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 52, color: Colors.white24),
            const SizedBox(height: 10),
            Text(
              'LIFETIME',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final int categoryId;
  const _CategoryChip({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    if (categoryId == 1) return const SizedBox.shrink(); // General

    final ds = sl<IsarCategoryDataSource>();
    final theme = Theme.of(context);

    return FutureBuilder(
      future: ds.fetchById(categoryId),
      builder: (context, snapshot) {
        final c = snapshot.data;
        if (c == null) return const SizedBox.shrink();
        if (c.name.trim().toLowerCase() == 'general') {
          return const SizedBox.shrink();
        }
        final color = Color(c.colorValue);
        final icon = _iconByName(c.iconName) ?? Icons.category_outlined;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                c.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

IconData? _iconByName(String name) {
  switch (name) {
    case 'cake':
      return Icons.cake_outlined;
    case 'favorite':
      return Icons.favorite_outline;
    case 'child_care':
      return Icons.child_care_outlined;
    case 'star':
      return Icons.star_outline;
    case 'celebration':
      return Icons.celebration_outlined;
    case 'photo':
      return Icons.photo_outlined;
    case 'travel':
      return Icons.flight_takeoff_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'work':
      return Icons.work_outline;
    case 'school':
      return Icons.school_outlined;
    case 'pets':
      return Icons.pets_outlined;
    case 'category':
    default:
      return Icons.category_outlined;
  }
}
