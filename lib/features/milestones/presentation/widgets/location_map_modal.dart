import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

/// Mapa modal de solo lectura centrado en unas coordenadas.
Future<void> showLocationMapModal(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? title,
  double zoom = 16.5,
}) {
  final label = (title ?? '').trim();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.72;
      return SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                label.isEmpty ? 'Ubicación del hito' : label,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _ReadOnlyLocationMap(
                  center: LatLng(latitude, longitude),
                  zoom: zoom,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 8),
          ],
        ),
      );
    },
  );
}

class _ReadOnlyLocationMap extends StatefulWidget {
  const _ReadOnlyLocationMap({
    required this.center,
    required this.zoom,
  });

  final LatLng center;
  final double zoom;

  @override
  State<_ReadOnlyLocationMap> createState() => _ReadOnlyLocationMapState();
}

class _ReadOnlyLocationMapState extends State<_ReadOnlyLocationMap> {
  final _mapController = MapController();
  var _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnPlace());
  }

  void _centerOnPlace() {
    if (!_mapReady) return;
    _mapController.move(widget.center, widget.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            onMapReady: () {
              _mapReady = true;
              _centerOnPlace();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'lifetime',
              tileProvider: NetworkTileProvider(
                cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                  maxCacheSize: 256 * 1024 * 1024,
                ),
              ),
            ),
          ],
        ),
        const IgnorePointer(
          child: Center(
            child: Icon(
              Icons.location_on,
              size: 46,
              color: AppTheme.navy,
            ),
          ),
        ),
      ],
    );
  }
}
