import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../utils/timeline_filters.dart';

/// Barra con chips de filtros activos (quitar uno o limpiar todos).
class TimelineActiveFiltersBar extends StatelessWidget {
  const TimelineActiveFiltersBar({
    super.key,
    required this.allMilestones,
    required this.filters,
    required this.onChanged,
  });

  final List<Milestone> allMilestones;
  final TimelineFilters filters;
  final ValueChanged<TimelineFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _personNames(filters.personIds),
      builder: (context, snapshot) {
        final personNames = snapshot.data ?? const {};
        final locations = collectLocationOptions(allMilestones);
        final chips = <Widget>[];

        for (final id in filters.personIds) {
          chips.add(
            _RemovableChip(
              label: personNames[id] ?? 'Persona',
              onRemove: () {
                final next = Set<String>.from(filters.personIds)..remove(id);
                onChanged(filters.copyWith(personIds: next));
              },
            ),
          );
        }
        for (final key in filters.locationKeys) {
          chips.add(
            _RemovableChip(
              label: locations[key] ?? 'Lugar',
              onRemove: () {
                final next = Set<String>.from(filters.locationKeys)..remove(key);
                onChanged(filters.copyWith(locationKeys: next));
              },
            ),
          );
        }
        for (final ym in filters.yearMonths) {
          chips.add(
            _RemovableChip(
              label: formatYearMonthLabel(ym.$1, ym.$2),
              onRemove: () {
                final next = Set<(int, int)>.from(filters.yearMonths)..remove(ym);
                onChanged(filters.copyWith(yearMonths: next));
              },
            ),
          );
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return Material(
          color: AppTheme.cream,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips,
                  ),
                ),
                TextButton(
                  onPressed: () => onChanged(TimelineFilters.empty),
                  child: const Text('Quitar todo'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _personNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final people = await sl<IsarPersonDataSource>().fetchByIds(ids.toList());
    return {
      for (final p in people)
        if (p.name.trim().isNotEmpty) p.id: p.name.trim(),
    };
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(
        label,
        style: const TextStyle(color: AppTheme.navy),
      ),
      deleteIcon: const Icon(Icons.close, size: 16, color: AppTheme.navy),
      onDeleted: onRemove,
      backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
      side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.25)),
    );
  }
}
