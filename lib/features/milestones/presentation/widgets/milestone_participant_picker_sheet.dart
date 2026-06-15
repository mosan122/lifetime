import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/person_display_helpers.dart';
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
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.75;
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
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rawAll = await widget.personDs.fetchAll();
      final raw = rawAll
          .where((p) => !widget.existingParticipantIds.contains(p.id))
          .toList();

      final milestones = await widget.milestoneDs.fetchAll();
      if (!mounted) return;

      final counts = <String, int>{};
      for (final m in milestones) {
        for (final pid in m.participants) {
          counts[pid] = (counts[pid] ?? 0) + 1;
        }
      }

      raw.sort(comparePeopleRootFirst);

      final suggestions = <PersonCollection>[];
      final root = raw.where((p) => p.isMe).firstOrNull;
      if (root != null) {
        suggestions.add(root);
      }
      for (final p in raw) {
        if (p.isMe) continue;
        if (suggestions.length >= 4) break;
        if ((counts[p.id] ?? 0) > 0) {
          suggestions.add(p);
        }
      }
      while (suggestions.length < 4 && suggestions.length < raw.length) {
        for (final p in raw) {
          if (suggestions.any((s) => s.id == p.id)) continue;
          suggestions.add(p);
          if (suggestions.length >= 4) break;
        }
        break;
      }

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

  List<PersonCollection> get _filtered {
    final list = _all;
    if (list == null) return const [];
    final q = _searchCtrl.text;
    return list.where((p) => personMatchesQuery(p, q)).toList();
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

  Widget _personTile(PersonCollection p, {bool suggested = false}) {
    return ListTile(
      tileColor: p.isMe ? AppTheme.navy.withValues(alpha: 0.06) : null,
      leading: PersonCircleAvatar(
        key: ValueKey<String>(
          '${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}|${suggested ? 's' : 'a'}',
        ),
        faceImagePath: p.faceImagePath,
        diameter: 40,
        semanticLabel: personDisplayName(p),
        borderWidth: p.isMe ? 2 : 0,
        borderColor: p.isMe ? AppTheme.navy : null,
      ),
      title: PersonListTitle(person: p),
      trailing: suggested
          ? Icon(
              p.isMe ? Icons.person_pin_outlined : Icons.star,
              color: p.isMe ? AppTheme.navy : Colors.amber,
              size: 20,
            )
          : null,
      onTap: () => Navigator.pop(context, p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchCtrl.text.trim();
    final showSuggestions = query.isEmpty && _quickSuggestions.isNotEmpty;
    final suggestionIds = _quickSuggestions.map((p) => p.id).toSet();
    final filtered = _filtered;
    final listPeople = showSuggestions
        ? filtered.where((p) => !suggestionIds.contains(p.id)).toList()
        : filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Text('Añadir al hito', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFAFAE8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                if (showSuggestions) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      'Sugerencias rápidas',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  ..._quickSuggestions.map(
                    (p) => _personTile(p, suggested: true),
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      'Todos los contactos',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
                if (listPeople.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      query.isNotEmpty
                          ? 'Ningún contacto coincide con la búsqueda.'
                          : showSuggestions
                              ? 'No hay más contactos disponibles.'
                              : 'Todos los contactos ya están en este hito, o aún no hay nadie en la agenda.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                  )
                else
                  ...listPeople.map((p) => _personTile(p)),
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
