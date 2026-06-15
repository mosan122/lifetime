import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_flags.dart';
import '../../../../core/notifiers/people_faces_revision_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_location_helpers.dart'
    show locationInlineLabel;
import '../../../../core/utils/milestone_display_helpers.dart';
import '../../../../injection_container.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../bloc/milestone_timeline_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/face_stack.dart';
import '../widgets/local_media_thumb.dart';
import '../widgets/milestone_category_chip.dart';
import '../widgets/timeline_active_filters_bar.dart';
import '../widgets/timeline_filter_sheet.dart';
import '../widgets/timeline_sync_status_indicator.dart';
import '../widgets/milestone_sync_badge.dart';
import '../../../profile/presentation/pages/local_user_profile_page.dart';
import '../../../../features/settings/presentation/bloc/people_cubit.dart';
import '../../../../features/settings/presentation/pages/manage_people_page.dart';
import '../../../../features/settings/presentation/pages/settings_page.dart';
import 'add_milestone_page.dart';
import 'milestones_map_page.dart';
import 'milestone_detail_page.dart';
import 'relationship_tree_view.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MilestoneTimelineCubit>()..loadTimeline(),
      child: const _AuthenticatedTimelineView(),
    );
  }
}

class _AuthenticatedTimelineView extends StatelessWidget {
  const _AuthenticatedTimelineView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeTime'),
        actions: [
          const TimelineSyncStatusIndicator(),
          BlocBuilder<MilestoneTimelineCubit, MilestoneTimelineState>(
            buildWhen: (prev, next) =>
                prev is MilestoneTimelineLoaded || next is MilestoneTimelineLoaded,
            builder: (context, state) {
              final active =
                  state is MilestoneTimelineLoaded && state.filters.isActive;
              return IconButton(
                icon: Badge(
                  isLabelVisible: active,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: 'Filtrar timeline',
                onPressed: state is! MilestoneTimelineLoaded
                    ? null
                    : () async {
                        final cubit = context.read<MilestoneTimelineCubit>();
                        final result = await showTimelineFilterSheet(
                          context: context,
                          allMilestones: state.allMilestones,
                          initial: state.filters,
                        );
                        if (result != null && context.mounted) {
                          cubit.setFilters(result);
                        }
                      },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Mapa de hitos',
            onPressed: () {
              final s = context.read<MilestoneTimelineCubit>().state;
              final milestones = s is MilestoneTimelineLoaded
                  ? s.milestones
                      .where((m) => m.latitude != null && m.longitude != null)
                      .toList()
                  : const <Milestone>[];
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MilestonesMapPage(
                    milestonesWithCoords: milestones,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Gestionar personas',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider(
                  create: (_) => sl<PeopleCubit>()..bootstrap(),
                  child: const ManagePeoplePage(),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Árbol genealógico',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                // Sin personId: el árbol se centra en el usuario raíz ("yo").
                builder: (_) => const RelationshipTreeView(),
              ),
            ),
          ),
          if (!AppFlags.kIsCloudEnabled)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Mi perfil',
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LocalUserProfilePage(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
              if (!context.mounted) return;
              await context.read<MilestoneTimelineCubit>().refreshTimeline();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TimelineSyncMediaProgressBar(),
          BlocBuilder<MilestoneTimelineCubit, MilestoneTimelineState>(
            buildWhen: (prev, next) =>
                prev is MilestoneTimelineLoaded || next is MilestoneTimelineLoaded,
            builder: (context, state) {
              if (state is! MilestoneTimelineLoaded || !state.filters.isActive) {
                return const SizedBox.shrink();
              }
              final cubit = context.read<MilestoneTimelineCubit>();
              return TimelineActiveFiltersBar(
                allMilestones: state.allMilestones,
                filters: state.filters,
                onChanged: cubit.setFilters,
              );
            },
          ),
          Expanded(
            child: BlocBuilder<MilestoneTimelineCubit, MilestoneTimelineState>(
              builder: (context, state) {
                if (state is MilestoneTimelineLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is MilestoneTimelineLoaded) {
                  if (state.allMilestones.isEmpty) {
                    return const _EmptyTimeline();
                  }
                  if (state.milestones.isEmpty) {
                    return _EmptyFilteredTimeline(
                      onClear: () =>
                          context.read<MilestoneTimelineCubit>().clearFilters(),
                      onEditFilters: () async {
                        final cubit = context.read<MilestoneTimelineCubit>();
                        final result = await showTimelineFilterSheet(
                          context: context,
                          allMilestones: state.allMilestones,
                          initial: state.filters,
                        );
                        if (result != null && context.mounted) {
                          cubit.setFilters(result);
                        }
                      },
                    );
                  }
                  return _MilestoneList(milestones: state.milestones);
                }
                if (state is MilestoneTimelineError) {
                  return ErrorRetryView(
                    title: 'No se pudo cargar la bitácora',
                    message: state.message,
                    onRetry: () =>
                        context.read<MilestoneTimelineCubit>().loadTimeline(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timeline_add_milestone',
        tooltip: 'Nuevo hito',
        onPressed: () async {
          final cubit = context.read<MilestoneTimelineCubit>();
          final didCreate = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddMilestonePage()),
          );
          if (didCreate == true) {
            cubit.loadTimeline();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── List (agrupado por año, un solo sticky) ─────────────────────────────────

/// Conserva el orden del timeline (eventDate descendente) y agrupa por año.
List<(int year, List<Milestone> items)> _groupMilestonesByYear(
    List<Milestone> milestones) {
  final map = <int, List<Milestone>>{};
  for (final m in milestones) {
    final y = m.eventDate.year;
    map.putIfAbsent(y, () => []).add(m);
  }
  final years = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final y in years) (y, map[y]!)];
}

class _TimelineYearHeader extends StatelessWidget {
  const _TimelineYearHeader({required this.year, required this.theme});

  final int year;
  final ThemeData theme;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final softBg =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92);
    return Material(
      color: softBg,
      elevation: 0.5,
      shadowColor: theme.dividerColor.withValues(alpha: 0.35),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$year',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneList extends StatefulWidget {
  final List<Milestone> milestones;
  const _MilestoneList({required this.milestones});

  @override
  State<_MilestoneList> createState() => _MilestoneListState();
}

class _MilestoneListState extends State<_MilestoneList> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _yearAnchorKeys = {};
  int? _stickyYear;

  GlobalKey _keyForYear(int year) =>
      _yearAnchorKeys.putIfAbsent(year, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateStickyYear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateStickyYear();
    });
  }

  @override
  void didUpdateWidget(covariant _MilestoneList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validYears = _groupMilestonesByYear(widget.milestones)
        .map((e) => e.$1)
        .toSet();
    _yearAnchorKeys.removeWhere((y, _) => !validYears.contains(y));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateStickyYear();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateStickyYear);
    _scrollController.dispose();
    super.dispose();
  }

  double? _yearSectionDy(int year) {
    final ctx = _yearAnchorKeys[year]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final viewportCtx = _scrollController.position.context.storageContext;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
  }

  void _updateStickyYear() {
    if (!mounted || !_scrollController.hasClients) return;
    final grouped = _groupMilestonesByYear(widget.milestones);
    if (grouped.isEmpty) return;

    // Año cuya cabecera está más cerca del borde superior (sin contar las ya
    // muy arriba del viewport).
    var activeYear = grouped.first.$1;
    var bestDy = double.negativeInfinity;

    for (final (year, _) in grouped) {
      final dy = _yearSectionDy(year);
      if (dy == null) continue;
      if (dy <= _TimelineYearHeader.height && dy > bestDy) {
        bestDy = dy;
        activeYear = year;
      }
    }

    if (_stickyYear != activeYear) {
      setState(() => _stickyYear = activeYear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupMilestonesByYear(widget.milestones);
    final stickyYear = _stickyYear ?? grouped.first.$1;

    return ListenableBuilder(
      listenable: sl<PeopleFacesRevisionNotifier>(),
      builder: (context, _) {
        final peopleDataRevision = sl<PeopleFacesRevisionNotifier>().value;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                for (final (year, items) in grouped) ...[
                  SliverToBoxAdapter(
                    key: _keyForYear(year),
                    child: SizedBox(
                      height: _TimelineYearHeader.height,
                      width: double.infinity,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = items[index];
                          final gap = index < items.length - 1 ? 12.0 : 20.0;
                          return Padding(
                            padding: EdgeInsets.only(bottom: gap),
                            child: _MilestoneCard(
                              milestone: m,
                              peopleDataRevision: peopleDataRevision,
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TimelineYearHeader(year: stickyYear, theme: theme),
            ),
          ],
        );
      },
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone milestone;
  final int peopleDataRevision;
  const _MilestoneCard({
    required this.milestone,
    required this.peopleDataRevision,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final accessToken =
        authState is AuthAuthenticated ? authState.user.accessToken : null;
    final canUseDrive = accessToken != null && accessToken.trim().isNotEmpty;
    final omitFaceForLinkedUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    if (milestone.mediaItems.isNotEmpty) {
      return _LocalMediaCard(
        milestone: milestone,
        accessToken: accessToken,
        peopleDataRevision: peopleDataRevision,
        omitFaceForLinkedUserId: omitFaceForLinkedUserId,
      );
    }

    if (milestone.driveFileId != null && canUseDrive) {
      return _MediaCard(
        milestone: milestone,
        accessToken: accessToken,
        peopleDataRevision: peopleDataRevision,
        omitFaceForLinkedUserId: omitFaceForLinkedUserId,
      );
    }
    return _TextCard(
      milestone: milestone,
      peopleDataRevision: peopleDataRevision,
      omitFaceForLinkedUserId: omitFaceForLinkedUserId,
    );
  }
}

// ── Card with local media preview ─────────────────────────────────────────────

class _LocalMediaCard extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;
  final int peopleDataRevision;
  final String? omitFaceForLinkedUserId;

  const _LocalMediaCard({
    required this.milestone,
    required this.accessToken,
    required this.peopleDataRevision,
    this.omitFaceForLinkedUserId,
  });

  Future<void> _openDetail(BuildContext context) async {
    final cubit = context.read<MilestoneTimelineCubit>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MilestoneDetailPage(
          milestone: milestone,
          accessToken: accessToken,
          onLocalMilestoneChanged: cubit.loadTimeline,
        ),
      ),
    );
    if (result != null) {
      cubit.loadTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatEventDate(milestone.eventDate);
    final title = milestone.title.trim();
    final hasTitle = title.isNotEmpty;
    final peopleLabelFallback = (milestone.participants.isEmpty)
        ? null
        : _peopleLabel(milestone.participants);

    final coverIdx = milestoneClampedGalleryCoverIndex(milestone);
    final cover = milestone.mediaItems[coverIdx];
    final isVideo = cover.mediaType == MediaType.video;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: MilestoneDetailPage.heroTag(milestone.id),
                    child: LocalMediaThumb(
                      item: cover,
                      fit: BoxFit.cover,
                      placeholderIconColor: Colors.white38,
                    ),
                  ),
                  if (isVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white70,
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: MilestoneSyncBadgeOverlay(milestone: milestone),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _DatePill(text: formatted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle || milestone.participantIds.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasTitle)
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          const Spacer(),
                        if (milestone.participantIds.isNotEmpty) ...[
                          if (hasTitle) const SizedBox(width: 8),
                          ParticipantFaceStack(
                            participantIds: milestone.participantIds,
                            protagonistIds: milestone.protagonistIds,
                            peopleDataRevision: peopleDataRevision,
                            omitFaceForLinkedUserId: omitFaceForLinkedUserId,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      MilestoneCategoryChip(categoryId: milestone.categoryId),
                      if (milestone.locationName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 11, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            locationInlineLabel(milestone),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (milestone.participantIds.isEmpty)
                        _PeopleMentionsInline(
                          participantIds: milestone.participantIds,
                          fallbackLabel: peopleLabelFallback,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card with Drive photo (premium) ──────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  final Milestone milestone;
  final String accessToken;
  final int peopleDataRevision;
  final String? omitFaceForLinkedUserId;
  const _MediaCard({
    required this.milestone,
    required this.accessToken,
    required this.peopleDataRevision,
    this.omitFaceForLinkedUserId,
  });

  Future<void> _openDetail(BuildContext context) async {
    final cubit = context.read<MilestoneTimelineCubit>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MilestoneDetailPage(
          milestone: milestone,
          accessToken: accessToken,
          onLocalMilestoneChanged: cubit.loadTimeline,
        ),
      ),
    );
    if (result != null) {
      cubit.loadTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatEventDate(milestone.eventDate);
    final title = milestone.title.trim();
    final hasTitle = title.isNotEmpty;
    final peopleLabelFallback = (milestone.participants.isEmpty)
        ? null
        : _peopleLabel(milestone.participants);

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo (no title overlay) ────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  child: Hero(
                    tag: MilestoneDetailPage.heroTag(milestone.id),
                    child: DriveThumbnail(
                      fileId: milestone.driveFileId!,
                      accessToken: accessToken,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: MilestoneSyncBadgeOverlay(milestone: milestone),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _DatePill(text: formatted),
                ),
              ],
            ),
          ),
          // ── Info strip ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle || milestone.participantIds.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasTitle)
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      if (milestone.participantIds.isNotEmpty) ...[
                        if (hasTitle) const SizedBox(width: 8),
                        ParticipantFaceStack(
                          participantIds: milestone.participantIds,
                          protagonistIds: milestone.protagonistIds,
                          peopleDataRevision: peopleDataRevision,
                          omitFaceForLinkedUserId: omitFaceForLinkedUserId,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    MilestoneCategoryChip(categoryId: milestone.categoryId),
                    if (milestone.locationName != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.place_outlined,
                          size: 11, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          locationInlineLabel(milestone),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (milestone.participantIds.isEmpty)
                      _PeopleMentionsInline(
                        participantIds: milestone.participantIds,
                        fallbackLabel: peopleLabelFallback,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),  // Card
    );   // GestureDetector
  }
}

// ── Text-only card ────────────────────────────────────────────────────────────

class _TextCard extends StatelessWidget {
  final Milestone milestone;
  final int peopleDataRevision;
  final String? omitFaceForLinkedUserId;
  const _TextCard({
    required this.milestone,
    required this.peopleDataRevision,
    this.omitFaceForLinkedUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatEventDate(milestone.eventDate);
    final title = milestone.title.trim();
    final hasTitle = title.isNotEmpty;
    final description = (milestone.description ?? '').trim();
    final hasDescription = description.isNotEmpty;
    final peopleLabelFallback = (milestone.participants.isEmpty)
        ? null
        : _peopleLabel(milestone.participants);

    return Card(
      child: InkWell(
        onTap: () async {
          final cubit = context.read<MilestoneTimelineCubit>();
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => MilestoneDetailPage(
                milestone: milestone,
                onLocalMilestoneChanged: cubit.loadTimeline,
              ),
            ),
          );
          if (result != null) {
            cubit.loadTimeline();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle || milestone.participantIds.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasTitle)
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          const Spacer(),
                        if (milestone.participantIds.isNotEmpty) ...[
                          if (hasTitle) const SizedBox(width: 8),
                          ParticipantFaceStack(
                            participantIds: milestone.participantIds,
                            protagonistIds: milestone.protagonistIds,
                            peopleDataRevision: peopleDataRevision,
                            omitFaceForLinkedUserId: omitFaceForLinkedUserId,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hasDescription) ...[
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: hasTitle ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Text(formatted, style: theme.textTheme.bodySmall),
                      const SizedBox(width: 6),
                      MilestoneSyncBadge(milestone: milestone),
                      if (milestone.locationName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 12,
                            color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            locationInlineLabel(milestone),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (milestone.participantIds.isEmpty)
                        _PeopleMentionsInline(
                          participantIds: milestone.participantIds,
                          fallbackLabel: peopleLabelFallback,
                          iconSize: 14,
                          gap: 4,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            MilestoneCategoryChip(categoryId: milestone.categoryId),
          ],
        ),
        ),    // Padding
      ),      // InkWell
    );        // Card
  }
}

class _DatePill extends StatelessWidget {
  final String text;
  const _DatePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String? _peopleLabel(List<String> people) {
  final cleaned = people.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (cleaned.isEmpty) return null;
  final first = cleaned.first;
  final extra = cleaned.length - 1;
  if (extra <= 0) return first;
  return '$first y $extra más';
}

class _PeopleMentionsInline extends StatelessWidget {
  final List<String> participantIds;
  final String? fallbackLabel;
  final double iconSize;
  final double gap;

  const _PeopleMentionsInline({
    required this.participantIds,
    required this.fallbackLabel,
    this.iconSize = 11,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<String>>(
      future: _loadPeopleNames(participantIds),
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String>[];
        final labelFromIds = names.isEmpty ? null : _peopleLabel(names);
        final text = labelFromIds ?? fallbackLabel;
        if (text == null || text.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        return Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 10),
              Icon(Icons.people_outline,
                  size: iconSize, color: theme.textTheme.bodySmall?.color),
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<List<String>> _loadPeopleNames(List<String> ids) async {
  if (ids.isEmpty) return const <String>[];
  final ds = sl<IsarPersonDataSource>();
  final people = await ds.fetchByIds(ids);
  final byId = {for (final p in people) p.id: p.name};
  return ids
      .map((id) => byId[id])
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

// ── Empty & Error ─────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: AppTheme.navy.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Tu bitácora está vacía',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Pulsa + para registrar tu primer hito.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilteredTimeline extends StatelessWidget {
  const _EmptyFilteredTimeline({
    required this.onClear,
    required this.onEditFilters,
  });

  final VoidCallback onClear;
  final VoidCallback onEditFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off,
                size: 56, color: AppTheme.navy.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'Ningún hito con estos filtros',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba a quitar algún filtro o ajusta la selección.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onEditFilters,
                  child: const Text('Cambiar filtros'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onClear,
                  child: const Text('Quitar filtros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
