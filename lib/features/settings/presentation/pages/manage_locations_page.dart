import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/exceptions/duplicate_saved_location_name_exception.dart';
import '../../../../core/models/milestone_location_data.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../milestones/presentation/pages/location_picker_page.dart';
import '../../../milestones/presentation/widgets/person_name_alert_dialog.dart';
import '../../../milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../../milestones/data/models/local/saved_location_collection.dart';
import '../../../../core/services/place_autocomplete_service.dart';
import '../../../sync/schedule_cloud_sync.dart';
import '../../../sync/data/services/sync_service.dart';

class ManageLocationsPage extends StatefulWidget {
  const ManageLocationsPage({super.key});

  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  final _ds = sl<IsarSavedLocationDataSource>();
  late Future<List<SavedLocationCollection>> _locationsFuture;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _load();
  }

  void _refresh() => setState(() => _locationsFuture = _load());

  Future<List<SavedLocationCollection>> _load() => _ds.fetchAll();

  Future<void> _openDetail(SavedLocationCollection item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedLocationDetailPage(initialIsarId: item.isarId),
      ),
    );
    _refresh();
  }

  Future<void> _openMap(List<SavedLocationCollection> items) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedLocationsMapPage(items: items),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Lugares'),
        actions: [
          FutureBuilder<List<SavedLocationCollection>>(
            future: _locationsFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <SavedLocationCollection>[];
              final hasCoords = items.any(
                (e) => e.latitude != null && e.longitude != null,
              );
              return IconButton(
                tooltip: 'Ver en el mapa',
                icon: const Icon(Icons.map_outlined),
                onPressed: hasCoords ? () => _openMap(items) : null,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SavedLocationCollection>>(
        future: _locationsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aún no has guardado lugares.\n\nCuando elijas un lugar en un hito, usa “Guardar en mis lugares”.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.navy.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SavedLocationTile(
              item: items[i],
              onTap: () => _openDetail(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  final SavedLocationCollection item;
  final VoidCallback onTap;

  const _SavedLocationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // La lista solo muestra nombre, ciudad y país (sin coordenadas ni icono).
    final subtitleParts = <String>[
      if ((item.city ?? '').trim().isNotEmpty) item.city!.trim(),
      if ((item.country ?? '').trim().isNotEmpty) item.country!.trim(),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Detalle de un lugar: mapa centrado + ficha (incluye coordenadas) y editar.
class SavedLocationDetailPage extends StatefulWidget {
  const SavedLocationDetailPage({super.key, required this.initialIsarId});

  final int initialIsarId;

  @override
  State<SavedLocationDetailPage> createState() =>
      _SavedLocationDetailPageState();
}

class _SavedLocationDetailPageState extends State<SavedLocationDetailPage> {
  final _ds = sl<IsarSavedLocationDataSource>();
  final _mapController = MapController();
  final _placeService = PlaceAutocompleteService();
  SavedLocationCollection? _item;
  bool _loading = true;
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final fresh = await _ds.fetchById(widget.initialIsarId);
    if (!mounted) return;
    setState(() {
      _item = fresh;
      _loading = false;
      _resolvedAddress = null;
    });
    final i = fresh;
    if (i != null && i.latitude != null && i.longitude != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(i.latitude!, i.longitude!), 15);
        } catch (_) {}
      });
      final stored = (i.address ?? '').trim();
      if (stored.isEmpty) {
        final rev = await _placeService.reverse(
          latitude: i.latitude!,
          longitude: i.longitude!,
        );
        if (!mounted) return;
        if (rev != null && rev.name.trim().isNotEmpty) {
          setState(() => _resolvedAddress = rev.name.trim());
        }
      }
    }
  }

  Future<void> _edit() async {
    final item = _item;
    if (item == null) return;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cream,
      builder: (_) => _LocationEditorSheet(initial: item),
    );
    if (didSave == true) await _reload();
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null) return;
    final milestoneCount = await sl<IsarMilestoneDataSource>()
        .countMilestonesUsingSavedLocation(item.isarId);
    if (!mounted) return;
    if (milestoneCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cream,
          title: const Text('No se puede borrar'),
          content: Text(
            '«${item.name}» está asociado a '
            '$milestoneCount '
            'hito${milestoneCount == 1 ? '' : 's'}. '
            'Quita este lugar de esos hitos antes de borrarlo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cream,
        title: const Text('Borrar lugar'),
        content: Text('¿Borrar "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    final clientId = item.clientId.trim();
    if (clientId.isNotEmpty && sl.isRegistered<SyncService>()) {
      unawaited(sl<SyncService>().deleteSavedLocationRemote(clientId));
    }
    await _ds.deleteById(item.isarId);
    scheduleCloudDataSync();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _item;
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Text(item?.name ?? 'Lugar'),
        actions: [
          if (item != null) ...[
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
              ? const Center(child: Text('Lugar no encontrado.'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: (item.latitude == null || item.longitude == null)
                          ? Center(
                              child: Text(
                                'Este lugar no tiene coordenadas.\nUsa “Editar” para situarlo en el mapa.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      item.latitude!,
                                      item.longitude!,
                                    ),
                                    initialZoom: 15,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'lifetime',
                                      tileProvider: NetworkTileProvider(
                                        cachingProvider:
                                            BuiltInMapCachingProvider
                                                .getOrCreateInstance(
                                          maxCacheSize: 256 * 1024 * 1024,
                                        ),
                                      ),
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            item.latitude!,
                                            item.longitude!,
                                          ),
                                          width: 46,
                                          height: 46,
                                          child: const Icon(
                                            Icons.location_on,
                                            size: 46,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    _DetailInfoPanel(
                      item: item,
                      resolvedAddress: _resolvedAddress,
                    ),
                  ],
                ),
    );
  }
}

class _DetailInfoPanel extends StatelessWidget {
  const _DetailInfoPanel({
    required this.item,
    this.resolvedAddress,
  });

  final SavedLocationCollection item;
  final String? resolvedAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = (item.address ?? '').trim().isNotEmpty
        ? item.address!.trim()
        : (resolvedAddress ?? '').trim();
    final place = <String>[
      if ((item.city ?? '').trim().isNotEmpty) item.city!.trim(),
      if ((item.country ?? '').trim().isNotEmpty) item.country!.trim(),
    ].join(', ');
    final hasCoords = item.latitude != null && item.longitude != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: AppTheme.navy.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ] else if (place.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(place, style: theme.textTheme.bodyMedium),
            ],
            if (hasCoords) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 16,
                    color: AppTheme.navy.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.latitude!.toStringAsFixed(5)}, '
                    '${item.longitude!.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mapa con todos los lugares guardados; al tocar un marcador se abre el detalle.
class SavedLocationsMapPage extends StatefulWidget {
  const SavedLocationsMapPage({super.key, required this.items});

  final List<SavedLocationCollection> items;

  @override
  State<SavedLocationsMapPage> createState() => _SavedLocationsMapPageState();
}

class _SavedLocationsMapPageState extends State<SavedLocationsMapPage> {
  final _mapController = MapController();

  List<SavedLocationCollection> get _withCoords => widget.items
      .where((e) => e.latitude != null && e.longitude != null)
      .toList();

  LatLng _centroid() {
    final pts = _withCoords;
    if (pts.isEmpty) return const LatLng(40.4168, -3.7038);
    final lat =
        pts.map((e) => e.latitude!).reduce((a, b) => a + b) / pts.length;
    final lon =
        pts.map((e) => e.longitude!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lon);
  }

  Future<void> _openDetail(SavedLocationCollection item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedLocationDetailPage(initialIsarId: item.isarId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(title: const Text('Mapa de lugares')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _centroid(),
          initialZoom: 4.4,
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
          MarkerLayer(
            markers: [
              for (final item in _withCoords)
                Marker(
                  point: LatLng(item.latitude!, item.longitude!),
                  width: 120,
                  height: 64,
                  child: GestureDetector(
                    onTap: () => _openDetail(item),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 40,
                          color: AppTheme.navy,
                        ),
                        Flexible(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.cream.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.navy,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationEditorSheet extends StatefulWidget {
  final SavedLocationCollection initial;
  const _LocationEditorSheet({required this.initial});

  @override
  State<_LocationEditorSheet> createState() => _LocationEditorSheetState();
}

class _LocationEditorSheetState extends State<_LocationEditorSheet> {
  late final TextEditingController _name;
  MilestoneLocationData? _picked;
  String? _geocodeAddress;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _geocodeAddress = widget.initial.address;
    _picked = MilestoneLocationData(
      name: widget.initial.name,
      city: widget.initial.city,
      country: widget.initial.country,
      latitude: widget.initial.latitude,
      longitude: widget.initial.longitude,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final ds = sl<IsarSavedLocationDataSource>();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar lugar', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  filled: true,
                  fillColor: const Color(0xFFFAFAE8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    side: const BorderSide(color: AppTheme.navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final picked = await Navigator.push<MilestoneLocationData>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPickerPage(
                          placeService: PlaceAutocompleteService(),
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    if (picked != null) {
                      final geocodeName = picked.name.trim();
                      final friendly = await showPersonNameAlertDialog(
                        context: context,
                        title: 'Nombre del lugar',
                        initialValue: _name.text.trim().isEmpty
                            ? picked.name
                            : _name.text.trim(),
                        hintText: 'Nombre amigable',
                        submitLabel: 'Usar',
                        textCapitalization: TextCapitalization.sentences,
                        useRootNavigator: true,
                      );
                      if (!context.mounted) return;
                      final chosen = (friendly ?? '').trim();
                      final displayName = chosen.isNotEmpty
                          ? chosen
                          : _name.text.trim().isNotEmpty
                              ? _name.text.trim()
                              : picked.name;
                      if (chosen.isNotEmpty) _name.text = chosen;
                      setState(() {
                        _geocodeAddress = geocodeName;
                        _picked = MilestoneLocationData(
                          name: displayName,
                          city: picked.city,
                          country: picked.country,
                          latitude: picked.latitude,
                          longitude: picked.longitude,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mover en el mapa'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    final oldName = widget.initial.name.trim();
                    final p = _picked;
                    String? trimOrNull(String? v) {
                      final t = v?.trim();
                      return (t == null || t.isEmpty) ? null : t;
                    }

                    final c = SavedLocationCollection()
                      ..isarId = widget.initial.isarId
                      ..clientId = widget.initial.clientId
                      ..name = name
                      ..address = trimOrNull(
                        _geocodeAddress ?? widget.initial.address,
                      )
                      ..city = trimOrNull(p?.city ?? widget.initial.city)
                      ..country = trimOrNull(p?.country ?? widget.initial.country)
                      ..latitude = p?.latitude ?? widget.initial.latitude
                      ..longitude = p?.longitude ?? widget.initial.longitude;
                    try {
                      await ds.upsert(c);
                    } on DuplicateSavedLocationNameException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                      return;
                    }
                    scheduleCloudDataSync();
                    if (oldName != name ||
                        widget.initial.latitude != c.latitude ||
                        widget.initial.longitude != c.longitude) {
                      try {
                        await sl<IsarMilestoneDataSource>()
                            .syncSavedLocationToMilestones(
                          savedLocationId: widget.initial.isarId,
                          name: name,
                          city: c.city,
                          country: c.country,
                          latitude: c.latitude,
                          longitude: c.longitude,
                        );
                      } catch (_) {
                        // Best-effort.
                      }
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
