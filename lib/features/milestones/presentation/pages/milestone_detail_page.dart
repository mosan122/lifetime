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
import '../../data/datasources/isar_person_datasource.dart';
import '../bloc/delete_milestone_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import 'add_milestone_page.dart';

class MilestoneDetailPage extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;

  const MilestoneDetailPage({
    super.key,
    required this.milestone,
    this.accessToken,
  });

  /// Stable Hero tag shared between source card and this page.
  static String heroTag(String milestoneId) => 'milestone-image-$milestoneId';

  /// Hero tag for a specific media index. Index 0 intentionally matches
  /// [heroTag] so the timeline can animate into the first item.
  static String heroMediaTag(String milestoneId, int index) =>
      index == 0 ? heroTag(milestoneId) : 'milestone-image-$milestoneId-$index';

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
      child: _DetailScaffold(milestone: milestone, accessToken: accessToken),
    );
  }
}

// ── Scaffold with delete listener ────────────────────────────────────────────

class _DetailScaffold extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;

  const _DetailScaffold({required this.milestone, this.accessToken});

  bool get _hasDriveHeaderImage =>
      milestone.driveFileId != null && accessToken != null;

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
    final isOwner = currentUserId == milestone.userId;
    final isDeleting =
        context.watch<DeleteMilestoneCubit>().state is DeleteMilestoneDeleting;

    final hasMediaItems = milestone.mediaItems.isNotEmpty;
    final expandedHeight = hasMediaItems
        ? 320.0
        : _hasDriveHeaderImage
            ? 300.0
            : 180.0;

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
                      builder: (_) => AddMilestonePage(initial: milestone),
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
              text: MilestoneDetailPage.formatForSharing(milestone),
              subject: milestone.title,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: hasMediaItems
            ? _MediaCarouselHeader(milestone: milestone)
            : _hasDriveHeaderImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: MilestoneDetailPage.heroTag(milestone.id),
                        child: DriveThumbnail(
                          fileId: milestone.driveFileId!,
                          accessToken: accessToken!,
                        ),
                      ),
                      const _GradientScrim(),
                    ],
                  )
                : _NoImageHeader(category: milestone.category),
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
            child: const Text(
              'Borrar',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      cubit.delete(milestone.id, accessToken: accessToken);
    }
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final d = milestone.eventDate;
    final formatted =
        '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
    final title = milestone.title.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(category: milestone.category),
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
          if (milestone.locationName != null) ...[
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
                    milestone.locationName!,
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
          _Narrative(description: milestone.description),
          const SizedBox(height: 18),
          _SemanticChips(
            participantIds: milestone.participantIds,
            tags: milestone.tags,
          ),
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
  final List<String> participantIds;
  final List<String> tags;

  const _SemanticChips({
    required this.participantIds,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (participantIds.isNotEmpty) ...[
          Text('Personas', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<String>>(
            future: _loadPeopleNames(participantIds),
            builder: (context, snapshot) {
              final names = snapshot.data ?? const <String>[];
              if (names.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: names
                    .map((name) => _Chip(label: name))
                    .toList(),
              );
            },
          ),
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

  Future<List<String>> _loadPeopleNames(List<String> ids) async {
    final ds = sl<IsarPersonDataSource>();
    final people = await ds.fetchByIds(ids);
    final byId = {for (final p in people) p.id: p.displayName};
    return ids
        .map((id) => byId[id])
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
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

// ── Media carousel header ─────────────────────────────────────────────────────

class _MediaCarouselHeader extends StatefulWidget {
  final Milestone milestone;
  const _MediaCarouselHeader({required this.milestone});

  @override
  State<_MediaCarouselHeader> createState() => _MediaCarouselHeaderState();
}

class _MediaCarouselHeaderState extends State<_MediaCarouselHeader> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.milestone.mediaItems;
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _controller,
                    physics: const PageScrollPhysics(),
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _MediaCarouselItem(
                      milestoneId: widget.milestone.id,
                      index: i,
                      items: items,
                      item: items[i],
                    ),
                  ),
                  const IgnorePointer(child: _GradientScrim()),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          _DotsIndicator(
                            count: items.length,
                            index: _index,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              '${_index + 1}/${items.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaCarouselItem extends StatelessWidget {
  final String milestoneId;
  final int index;
  final List<MediaItem> items;
  final MediaItem item;

  const _MediaCarouselItem({
    required this.milestoneId,
    required this.index,
    required this.items,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final tag = MilestoneDetailPage.heroMediaTag(milestoneId, index);
    final isVideo = item.mediaType == MediaType.video;

    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () => _openFullScreen(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: tag,
              child: _LocalMediaPreview(item: item),
            ),
            if (isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 68,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFullScreen(BuildContext context) async {
    if (items.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogCtx) => _MediaGalleryDialog(
        milestoneId: milestoneId,
        items: items,
        initialIndex: index,
      ),
    );
  }
}

class _MediaGalleryDialog extends StatelessWidget {
  final String milestoneId;
  final List<MediaItem> items;
  final int initialIndex;

  const _MediaGalleryDialog({
    required this.milestoneId,
    required this.items,
    required this.initialIndex,
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
              final heroTag = MilestoneDetailPage.heroMediaTag(milestoneId, i);

              if (it.mediaType == MediaType.video) {
                return PhotoViewGalleryPageOptions.customChild(
                  heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                  child: _VideoGalleryPage(
                    thumbnailPath: it.thumbnailPath,
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
  final String thumbnailPath;
  final VoidCallback onPlay;

  const _VideoGalleryPage({
    required this.thumbnailPath,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(thumbnailPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.movie_outlined, size: 56, color: Colors.white24),
            ),
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

class _LocalMediaPreview extends StatelessWidget {
  final MediaItem item;
  const _LocalMediaPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final path = item.mediaType == MediaType.video
        ? item.thumbnailPath
        : item.localPath;

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Colors.black12,
        child: Center(
          child: Icon(
            item.mediaType == MediaType.video
                ? Icons.movie_outlined
                : Icons.image_outlined,
            size: 40,
            color: Colors.white30,
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
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
  final String category;
  const _NoImageHeader({required this.category});

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
              category.toUpperCase(),
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

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
