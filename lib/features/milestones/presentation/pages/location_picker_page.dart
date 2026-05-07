import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/models/milestone_location_data.dart';
import '../../../../core/services/place_autocomplete_service.dart';
import '../../../../core/theme/app_theme.dart';

class LocationPickerPage extends StatefulWidget {
  final PlaceAutocompleteService placeService;
  final LatLng? initialCenter;

  const LocationPickerPage({
    super.key,
    required this.placeService,
    this.initialCenter,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  LatLng _center = const LatLng(40.4168, -3.7038); // Madrid fallback
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) _center = widget.initialCenter!;
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      final res = await widget.placeService.reverse(
        latitude: _center.latitude,
        longitude: _center.longitude,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        res ??
            MilestoneLocationData(
              name:
                  '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
              latitude: _center.latitude,
              longitude: _center.longitude,
            ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirming ? null : _confirm,
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: _confirming
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check),
        label: const Text('Confirmar ubicación'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: (pos, _) {
                _center = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lifetime',
                tileProvider: NetworkTileProvider(
                  cachingProvider:
                      BuiltInMapCachingProvider.getOrCreateInstance(
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
      ),
    );
  }
}

