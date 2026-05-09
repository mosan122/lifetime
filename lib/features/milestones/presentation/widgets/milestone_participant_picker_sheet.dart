import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/person_collection.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import 'person_avatar_badge.dart';
import 'quick_create_person_sheet.dart';

/// Hoja para elegir una persona ya existente o crear una nueva y añadirla al hito.
Future<PersonCollection?> showMilestoneParticipantPickerSheet({
  required BuildContext context,
  required Set<String> existingParticipantIds,
  required IsarPersonDataSource personDs,
  required IsarMilestoneDataSource milestoneDs,
}) {
  return showModalBottomSheet<PersonCollection?>(
    context: context,
    backgroundColor: AppTheme.cream,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.62;
      return SafeArea(
        child: SizedBox(
          height: maxH,
          child: _MilestoneParticipantPickerBody(
            existingParticipantIds: existingParticipantIds,
            personDs: personDs,
            milestoneDs: milestoneDs,
          ),
        ),
      );
    },
  );
}

class _MilestoneParticipantPickerBody extends StatefulWidget {
  final Set<String> existingParticipantIds;
  final IsarPersonDataSource personDs;
  final IsarMilestoneDataSource milestoneDs;

  const _MilestoneParticipantPickerBody({
    required this.existingParticipantIds,
    required this.personDs,
    required this.milestoneDs,
  });

  @override
  State<_MilestoneParticipantPickerBody> createState() =>
      _MilestoneParticipantPickerBodyState();
}

class _MilestoneParticipantPickerBodyState
    extends State<_MilestoneParticipantPickerBody> {
  List<PersonCollection>? _all;
  Object? _loadError;
  List<PersonCollection> _quickSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.personDs.fetchAll();
      final milestones = await widget.milestoneDs.fetchAll();
      if (!mounted) return;
      final counts = <String, int>{};
      for (final m in milestones) {
        for (final pid in m.participants) {
          counts[pid] = (counts[pid] ?? 0) + 1;
        }
      }
      raw.sort((a, b) {
        final ca = counts[a.id] ?? 0;
        final cb = counts[b.id] ?? 0;
        if (cb != ca) return cb.compareTo(ca);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final suggestions = raw
          .where((p) => !widget.existingParticipantIds.contains(p.id))
          .take(3)
          .toList();

      raw.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      setState(() {
        _all = raw;
        _quickSuggestions = suggestions;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  List<PersonCollection> get _available {
    final list = _all;
    if (list == null) return const [];
    return list
        .where((p) => !widget.existingParticipantIds.contains(p.id))
        .toList();
  }

  Future<void> _createNew() async {
    final created = await showQuickCreatePersonSheet(
      context: context,
      personDs: widget.personDs,
      useRootNavigator: true,
    );
    if (!mounted) return;
    if (created != null) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Text(
                'Añadir al hito',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        if (_loadError != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la lista.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.red.shade800),
                ),
              ),
            ),
          )
        else if (_all == null)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (_quickSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Sugerencias rápidas',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  ..._quickSuggestions.map(
                    (p) => ListTile(
                      leading: PersonCircleAvatar(
                        key: ValueKey<String>(
                          '${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}|suggested',
                        ),
                        faceImagePath: p.faceImagePath,
                        diameter: 40,
                        semanticLabel: p.name,
                      ),
                      title: Text(p.name),
                      trailing: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                ],
                if (_available.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Todos los contactos ya están en este hito, o aún no hay nadie en la agenda.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                  )
                else
                  ..._available.map(
                    (p) => ListTile(
                      leading: PersonCircleAvatar(
                        key: ValueKey<String>(
                          '${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}',
                        ),
                        faceImagePath: p.faceImagePath,
                        diameter: 40,
                        semanticLabel: p.name,
                      ),
                      title: Text(p.name),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _createNew,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Crear persona nueva'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: AppTheme.cream,
            ),
          ),
        ),
      ],
    );
  }
}
