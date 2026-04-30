import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/map_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import 'milestone_detail_page.dart';

class MapExplorerPage extends StatelessWidget {
  const MapExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MapCubit>()..loadMap(),
      child: const _MapView(),
    );
  }
}

// ── Map view (stateful for GoogleMapController lifecycle) ─────────────────────

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _showPreview(BuildContext context, Milestone milestone) {
    final authState = context.read<AuthCubit>().state;
    final accessToken =
        authState is AuthAuthenticated ? authState.user.accessToken : null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _MilestonePreviewSheet(
        milestone: milestone,
        accessToken: accessToken,
        onViewDetail: () async {
          Navigator.pop(sheetCtx);
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => MilestoneDetailPage(
                milestone: milestone,
                accessToken: accessToken,
              ),
            ),
          );
          if (result != null && context.mounted) {
            context.read<MapCubit>().loadMap();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Hitos'),
        actions: [
          BlocBuilder<MapCubit, MapState>(
            buildWhen: (_, curr) => curr is MapLoaded,
            builder: (_, state) {
              if (state is! MapLoaded) return const SizedBox.shrink();
              final count = state.locatedMilestones.length;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: _CountBadge(count: count)),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<MapCubit, MapState>(
        builder: (context, state) {
          if (state is MapInitial || state is MapLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MapError) {
            return _MapErrorView(
              message: state.message,
              onRetry: () => context.read<MapCubit>().loadMap(),
            );
          }
          if (state is MapLoaded) {
            if (state.locatedMilestones.isEmpty) {
              return const _NoLocationView();
            }
            return _buildMap(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, MapLoaded state) {
    final center = _centroid(state.locatedMilestones);
    final markers = state.locatedMilestones
        .map(
          (m) => Marker(
            markerId: MarkerId(m.id),
            position: LatLng(m.latitude!, m.longitude!),
            onTap: () => _showPreview(context, m),
          ),
        )
        .toSet();

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 5),
      markers: markers,
      onMapCreated: (c) => _controller = c,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  // Average of all marker positions — gives a reasonable initial camera center.
  static LatLng _centroid(List<Milestone> milestones) {
    final avgLat =
        milestones.map((m) => m.latitude!).reduce((a, b) => a + b) /
            milestones.length;
    final avgLng =
        milestones.map((m) => m.longitude!).reduce((a, b) => a + b) /
            milestones.length;
    return LatLng(avgLat, avgLng);
  }
}

// ── Milestone preview sheet ───────────────────────────────────────────────────

class _MilestonePreviewSheet extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;
  final VoidCallback? onViewDetail;

  const _MilestonePreviewSheet({
    required this.milestone,
    this.accessToken,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = milestone.eventDate;
    final formatted =
        '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
    final hasThumbnail = milestone.driveFileId != null && accessToken != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4D4B8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D4B8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (hasThumbnail)
              ClipRRect(
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: DriveThumbnail(
                    fileId: milestone.driveFileId!,
                    accessToken: accessToken!,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(formatted, style: theme.textTheme.bodySmall),
                  if (milestone.locationName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
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
                  if (onViewDetail != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onViewDetail,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          side: const BorderSide(color: AppTheme.navy),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Ver hito completo'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count hito${count == 1 ? '' : 's'}',
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NoLocationView extends StatelessWidget {
  const _NoLocationView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 64, color: AppTheme.navy.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Sin hitos en el mapa', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Los hitos con ubicación aparecerán aquí.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MapErrorView({required this.message, required this.onRetry});

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
            Text('No se pudo cargar el mapa',
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
