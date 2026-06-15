import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../utils/map_location_helpers.dart' show centerMapOnCurrentLocation;
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/milestone_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_location_helpers.dart'
    show milestonesCentroid;
import '../../../../domain/entities/milestone.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../widgets/drive_thumbnail.dart';
import '../widgets/local_media_thumb.dart';
import '../widgets/milestone_count_badge.dart';
import '../widgets/milestone_preview_content.dart';
import 'milestone_detail_page.dart';

class MilestonesMapPage extends StatefulWidget {
  final List<Milestone> milestonesWithCoords;

  const MilestonesMapPage({
    super.key,
    required this.milestonesWithCoords,
  });

  @override
  State<MilestonesMapPage> createState() => _MilestonesMapPageState();
}

class _MilestonesMapPageState extends State<MilestonesMapPage> {
  final _mapController = MapController();

  Milestone? _selected;

  @override
  Widget build(BuildContext context) {
    final milestones = widget.milestonesWithCoords
        .where((m) => m.latitude != null && m.longitude != null)
        .toList();
    final markerPoints = _withJitter(milestones);

    final authState = context.read<AuthCubit>().state;
    final accessToken =
        authState is AuthAuthenticated ? authState.user.accessToken : null;
    final canUseDrive = accessToken != null && accessToken.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Hitos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Centrar en mi posición',
            onPressed: () => _centerOnMyLocation(),
          ),
          if (milestones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: MilestoneCountBadge(count: milestones.length)),
            ),
        ],
      ),
      body: milestones.isEmpty
          ? const _NoLocationView()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centroid(milestones),
                    initialZoom: 4.4,
                    onMapReady: () {
                      _mapController.move(_centroid(milestones), 4.4);
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'lifetime',
                      // Cache de tiles (flutter_map 8: caching integrado en nativo).
                      tileProvider: NetworkTileProvider(
                        cachingProvider:
                            BuiltInMapCachingProvider.getOrCreateInstance(
                          maxCacheSize: 256 * 1024 * 1024, // 256MB aprox
                        ),
                      ),
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        disableClusteringAtZoom: 16,
                        size: const Size(44, 44),
                        alignment: Alignment.center,
                        markers: [
                          for (final entry in markerPoints)
                            Marker(
                              width: 44,
                              height: 44,
                              point: entry.point,
                              child: _MilestoneMarker(
                                milestone: entry.milestone,
                                accessToken: canUseDrive ? accessToken : null,
                                onTap: () => _onMarkerTap(
                                  entry.milestone,
                                  entry.point,
                                ),
                              ),
                            ),
                        ],
                        markerChildBehavior: true,
                        builder: (context, cluster) {
                          return _ClusterBubble(count: cluster.length);
                        },
                        onClusterTap: (clusterNode) {
                          final zoom = _mapController.camera.zoom;
                          _mapController.move(
                            clusterNode.bounds.center,
                            (zoom + 1.2).clamp(3.0, 18.0),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_selected != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _MilestonePreviewCard(
                        milestone: _selected!,
                        accessToken: canUseDrive ? accessToken : null,
                        onViewDetail: () => _openDetail(context, _selected!,
                            accessToken: canUseDrive ? accessToken : null),
                        onClose: () => setState(() => _selected = null),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _onMarkerTap(Milestone m, LatLng point) {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      point,
      currentZoom < 13 ? 13 : currentZoom,
    );
    setState(() => _selected = m);
  }

  Future<void> _centerOnMyLocation() async {
    await centerMapOnCurrentLocation(context, _mapController, zoom: 14);
  }

  Future<void> _openDetail(
    BuildContext context,
    Milestone milestone, {
    required String? accessToken,
  }) async {
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
      Navigator.pop(context, result);
    }
  }

  static LatLng _centroid(List<Milestone> milestones) {
    final (lat, lng) = milestonesCentroid(milestones);
    return LatLng(lat, lng);
  }

  /// Si hay hitos con coordenadas idénticas, aplica un desvío mínimo (jitter)
  /// para evitar que parezcan un solo marcador ("efecto túnel").
  static List<_MarkerEntry> _withJitter(List<Milestone> milestones) {
    final byKey = <String, List<Milestone>>{};
    for (final m in milestones) {
      final lat = m.latitude!;
      final lon = m.longitude!;
      final key = '${lat.toStringAsFixed(7)},${lon.toStringAsFixed(7)}';
      (byKey[key] ??= <Milestone>[]).add(m);
    }

    final out = <_MarkerEntry>[];
    for (final entry in byKey.entries) {
      final list = entry.value;
      if (list.length == 1) {
        final m = list.first;
        out.add(_MarkerEntry(
          milestone: m,
          point: LatLng(m.latitude!, m.longitude!),
        ));
        continue;
      }

      // ~0.5m en lat; en lon ajustamos por cos(lat) para que sea parecido en metros.
      final baseLat = list.first.latitude!;
      final baseLon = list.first.longitude!;
      final metersToDegLat = 1 / 111000.0;
      final latCos =
          math.cos(baseLat * 0.01745329252).abs().clamp(0.2, 1.0);
      final metersToDegLon = 1 / (111000.0 * latCos);
      // Unos metros para que a zoom alto se vean separados.
      const radiusMeters = 3.0;

      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        final angle = (i * 2.399963229728653); // golden angle
        final r = radiusMeters * (0.35 + (i / list.length));
        final dLat = (r * metersToDegLat) * (math.sin(angle));
        final dLon = (r * metersToDegLon) * (math.cos(angle));
        out.add(_MarkerEntry(
          milestone: m,
          point: LatLng(baseLat + dLat, baseLon + dLon),
        ));
      }
    }
    return out;
  }
}

class _MarkerEntry {
  final Milestone milestone;
  final LatLng point;
  const _MarkerEntry({required this.milestone, required this.point});
}

class _MilestoneMarker extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;
  final VoidCallback onTap;

  const _MilestoneMarker({
    required this.milestone,
    required this.accessToken,
    required this.onTap,
  });

  int _clampCoverIndex() {
    final n = milestone.mediaItems.length;
    if (n <= 0) return 0;
    return milestone.galleryCoverIndex.clamp(0, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final category = milestoneCategoryById(milestone.categoryId);
    final border = category.color;

    final hasLocalCover = milestone.mediaItems.isNotEmpty;
    final hasDriveCover = milestone.driveFileId != null &&
        accessToken != null &&
        accessToken?.trim().isNotEmpty == true;

    Widget thumb;
    if (hasLocalCover) {
      final cover = milestone.mediaItems[_clampCoverIndex()];
      thumb = LocalMediaThumb(
        item: cover,
        fit: BoxFit.cover,
        placeholderIconColor: AppTheme.navy.withValues(alpha: 0.3),
      );
    } else if (hasDriveCover) {
      thumb = DriveThumbnail(
        fileId: milestone.driveFileId!,
        accessToken: accessToken!,
      );
    } else {
      thumb = ColoredBox(
        color: const Color(0xFFFAFAE8),
        child: Center(
          child: Icon(category.icon, size: 18, color: border),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2.2),
          boxShadow: const [AppTheme.cardShadow],
        ),
        child: ClipOval(child: thumb),
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  final int count;
  const _ClusterBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cream, width: 2),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MilestonePreviewCard extends StatelessWidget {
  final Milestone milestone;
  final String? accessToken;
  final VoidCallback onViewDetail;
  final VoidCallback onClose;

  const _MilestonePreviewCard({
    required this.milestone,
    required this.accessToken,
    required this.onViewDetail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal = milestone.mediaItems.isNotEmpty;
    final hasDrive = milestone.driveFileId != null &&
        accessToken != null &&
        accessToken?.trim().isNotEmpty == true;

    Widget? header;
    if (hasLocal) {
      final idx = milestone.mediaItems.isEmpty
          ? 0
          : milestone.galleryCoverIndex.clamp(0, milestone.mediaItems.length - 1);
      header = SizedBox(
        height: 130,
        width: double.infinity,
        child: LocalMediaThumb(
          item: milestone.mediaItems[idx],
          fit: BoxFit.cover,
          placeholderIconColor: AppTheme.navy.withValues(alpha: 0.25),
        ),
      );
    } else if (hasDrive) {
      header = SizedBox(
        height: 130,
        width: double.infinity,
        child: DriveThumbnail(
          fileId: milestone.driveFileId!,
          accessToken: accessToken!,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: header,
              ),
            MilestonePreviewContent(
              milestone: milestone,
              onViewDetail: onViewDetail,
              titleFallback: 'Hito',
              trailingAction: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: AppTheme.navy.withValues(alpha: 0.7),
                tooltip: 'Cerrar',
              ),
              useFullLocationLabel: true,
              buttonBorderRadius: 10.0,
            ),
          ],
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

