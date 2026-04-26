import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../../domain/entities/milestone.dart';
import '../bloc/milestone_timeline_cubit.dart';
import 'add_milestone_page.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MilestoneTimelineCubit>()..loadTimeline(),
      child: const _TimelineView(),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Bitácora')),
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
          // Capture cubit before the async gap to avoid context warnings
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
    final theme = Theme.of(context);
    final date = milestone.eventDate;
    final formatted =
        '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent strip
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
                  Text(
                    milestone.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(formatted, style: theme.textTheme.bodySmall),
                  if (milestone.locationName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 12, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Text(milestone.locationName!,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _CategoryBadge(category: milestone.category),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha:0.08),
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
                size: 64, color: AppTheme.navy.withValues(alpha:0.3)),
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
