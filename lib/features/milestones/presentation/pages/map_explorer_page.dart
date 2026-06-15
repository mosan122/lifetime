import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_location_helpers.dart';
import '../../../../core/utils/milestone_display_helpers.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/map_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/milestone_count_badge.dart';
import '../widgets/milestone_preview_content.dart';
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
                onLocalMilestoneChanged: () {
                  if (context.mounted) {
                    context.read<MapCubit>().loadMap();
                  }
                },
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
                child: Center(child: MilestoneCountBadge(count: count)),
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
            return ErrorRetryView(
              title: 'No se pudo cargar el mapa',
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
    final (lat, lng) = milestonesCentroid(milestones);
    return LatLng(lat, lng);
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
    final hasThumbnail = milestone.driveFileId != null && accessToken != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
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
                  color: AppTheme.divider,
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
            MilestonePreviewContent(
              milestone: milestone,
              onViewDetail: onViewDetail,
              infoPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              buttonPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              largeTitleStyle: true,
              useFullLocationLabel: false,
              buttonBorderRadius: 8.0,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

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
