import 'package:flutter/material.dart';

import '../../../../core/models/milestone_location_data.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../milestones/presentation/pages/location_picker_page.dart';
import '../../../milestones/presentation/widgets/person_name_alert_dialog.dart';
import '../../../milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../../milestones/data/models/local/saved_location_collection.dart';
import '../../../../core/services/place_autocomplete_service.dart';

class ManageLocationsPage extends StatefulWidget {
  const ManageLocationsPage({super.key});

  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  final _ds = sl<IsarSavedLocationDataSource>();

  Future<void> _refresh() async => setState(() {});

  Future<List<SavedLocationCollection>> _load() => _ds.fetchAll();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(title: const Text('Lugares')),
      body: FutureBuilder<List<SavedLocationCollection>>(
        future: _load(),
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
              onChanged: _refresh,
            ),
          );
        },
      ),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  final SavedLocationCollection item;
  final Future<void> Function() onChanged;

  const _SavedLocationTile({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ds = sl<IsarSavedLocationDataSource>();

    final subtitleParts = <String>[
      if ((item.city ?? '').trim().isNotEmpty) item.city!.trim(),
      if ((item.country ?? '').trim().isNotEmpty) item.country!.trim(),
      if (item.latitude != null && item.longitude != null)
        '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
          foregroundColor: AppTheme.navy,
          child: const Icon(Icons.place_outlined),
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (v) async {
            if (v == 'edit') {
              final didSave = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.cream,
                builder: (_) => _LocationEditorSheet(initial: item),
              );
              if (didSave == true) await onChanged();
            }
            if (v == 'delete') {
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
                      child: const Text(
                        'Borrar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ds.deleteById(item.isarId);
                await onChanged();
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar nombre')),
            PopupMenuItem(value: 'delete', child: Text('Borrar')),
          ],
        ),
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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
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
                      setState(
                        () => _picked = MilestoneLocationData(
                          name: displayName,
                          city: picked.city,
                          country: picked.country,
                          latitude: picked.latitude,
                          longitude: picked.longitude,
                        ),
                      );
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
                      ..city = trimOrNull(p?.city ?? widget.initial.city)
                      ..country = trimOrNull(p?.country ?? widget.initial.country)
                      ..latitude = p?.latitude ?? widget.initial.latitude
                      ..longitude = p?.longitude ?? widget.initial.longitude;
                    await ds.upsert(c);
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

