import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/group_icon_helpers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../bloc/people_cubit.dart';

/// Pestaña para asignar varios grupos a la persona (chips + crear grupo).
class EditPersonGroupsTab extends StatelessWidget {
  const EditPersonGroupsTab({
    super.key,
    required this.allGroups,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<GroupCollection> allGroups;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  Future<void> _createGroup(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nuevo grupo'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Club de lectura',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (!context.mounted || name == null || name.isEmpty) return;

      try {
        final id =
            await sl<PersonGroupLocalDataSource>().createCustomGroup(name);
        if (!context.mounted) return;
        await context.read<PeopleCubit>().reload();
        if (!context.mounted) return;
        final next = [...selectedIds];
        if (!next.contains(id)) next.add(id);
        onChanged(next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo creado')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      ctrl.dispose();
    }
  }

  void _toggle(String groupId, List<String> current) {
    final next = [...current];
    final i = next.indexOf(groupId);
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.add(groupId);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (allGroups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No hay grupos disponibles.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _createGroup(context),
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Marca los grupos a los que pertenece esta persona.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in allGroups)
              FilterChip(
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
                  child: Icon(
                    groupIconFor(g.id),
                    size: 16,
                    color: AppTheme.navy,
                  ),
                ),
                label: Text(g.name),
                selected: selectedIds.contains(g.id),
                onSelected: (_) => _toggle(g.id, selectedIds),
                selectedColor: AppTheme.navy.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.navy,
              ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _createGroup(context),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Crear grupo nuevo'),
        ),
      ],
    );
  }
}
