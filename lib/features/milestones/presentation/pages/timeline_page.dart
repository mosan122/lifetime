import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../data/datasources/isar_category_datasource.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../bloc/milestone_timeline_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import '../widgets/face_stack.dart';
import '../widgets/local_media_thumb.dart';
import '../../../../features/settings/presentation/pages/settings_page.dart';
import 'add_milestone_page.dart';
import 'map_explorer_page.dart';
import 'milestone_detail_page.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MilestoneTimelineCubit>(),
      child: const _TimelineView(),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          prev is! AuthAuthenticated && curr is AuthAuthenticated,
      listener: (context, _) =>
          context.read<MilestoneTimelineCubit>().loadTimeline(),
      builder: (context, authState) {
        if (authState is AuthAuthenticating) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authState is! AuthAuthenticated) {
          final error = authState is AuthUnauthenticated ? authState.error : null;
          return _ConnectView(error: error);
        }
        return const _AuthenticatedTimelineView();
      },
    );
  }
}

// ── Unauthenticated ───────────────────────────────────────────────────────────

class _ConnectView extends StatelessWidget {
  final String? error;
  const _ConnectView({this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 72, color: AppTheme.navy.withValues(alpha: 0.25)),
                const SizedBox(height: 24),
                Text('Tu Bitácora de Vida',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Conecta tu Google Drive para guardar tus hitos de forma segura y privada.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.red.shade700),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text(
                      'Iniciar sesión con Google',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () =>
                        context.read<AuthCubit>().signInWithGoogle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Authenticated ─────────────────────────────────────────────────────────────

class _AuthenticatedTimelineView extends StatelessWidget {
  const _AuthenticatedTimelineView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeTime'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Mapa de hitos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MapExplorerPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: BlocBuilder<MilestoneTimelineCubit, MilestoneTimelineState>(
        builder: (context, state) {
          if (state is MilestoneTimelineLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MilestoneTimelineLoaded) {
            if (state.milestones.isEmpty) {
              return const _EmptyTimeline();
            }
            return _MilestoneList(milestones: state.milestones);
          }
          if (state is MilestoneTimelineError) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<MilestoneTimelineCubit>().loadTimeline(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
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

// ── List ──────────────────────────────────────────────────────────────────────

class _MilestoneList extends StatelessWidget {
  final List<Milestone> milestones;
  const _MilestoneList({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: milestones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _MilestoneCard(milestone: milestones[index]),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone milestone;
  const _MilestoneCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final accessToken =
        authState is AuthAuthenticated ? authState.user.accessToken : null;

    if (milestone.mediaItems.isNotEmpty) {
      return _LocalMediaCard(milestone: milestone, accessToken: accessToken);
    }

    if (milestone.driveFileId != null && accessToken != null) {
      return _MediaCard(
          milestone: milestone, accessToken: accessToken);
    }
    return _TextCard(milestone: milestone);
  }
}

// ── Card with local media preview ─────────────────────────────────────────────

class _LocalMediaCard extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;

  const _LocalMediaCard({required this.milestone, required this.accessToken});

  Future<void> _openDetail(BuildContext context) async {
    final cubit = context.read<MilestoneTimelineCubit>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MilestoneDetailPage(
          milestone: milestone,
          accessToken: accessToken,
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
    final date = milestone.eventDate;
    final formatted =
        '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';
    final title = milestone.title.trim();
    final hasTitle = title.isNotEmpty;
    final peopleLabelFallback = (milestone.participants.isEmpty)
        ? null
        : _peopleLabel(milestone.participants);

    final first = milestone.mediaItems.first;
    final isVideo = first.mediaType == MediaType.video;

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
                      item: first,
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
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      _CategoryChip(categoryId: milestone.categoryId),
                      if (milestone.locationName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 11, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            milestone.locationName!,
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
  const _MediaCard({required this.milestone, required this.accessToken});

  Future<void> _openDetail(BuildContext context) async {
    final cubit = context.read<MilestoneTimelineCubit>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MilestoneDetailPage(
          milestone: milestone,
          accessToken: accessToken,
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
    final date = milestone.eventDate;
    final formatted =
        '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';
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
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    _CategoryChip(categoryId: milestone.categoryId),
                    if (milestone.locationName != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.place_outlined,
                          size: 11, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          milestone.locationName!,
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
  const _TextCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = milestone.eventDate;
    final formatted =
        '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';
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
              builder: (_) => MilestoneDetailPage(milestone: milestone),
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
                      if (milestone.locationName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 12,
                            color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            milestone.locationName!,
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
            _CategoryChip(categoryId: milestone.categoryId),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_off_outlined,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('No se pudo cargar la bitácora',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navy,
                side: const BorderSide(color: AppTheme.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
