import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';
import '../pages/edit_person_page.dart';
import 'person_detail_relationship_tree.dart';

/// Ficha de persona (vista) reutilizable desde hitos, grupos, etc.
Future<void> showPersonDetailSheet(
  BuildContext context, {
  required PersonCollection person,
  List<GroupCollection>? groups,
  bool allowEdit = true,
}) async {
  final allGroups = groups ??
      await sl<PersonGroupLocalDataSource>().fetchAllGroupsOrdered();
  if (!context.mounted) return;

  final groupIds =
      (await sl<PersonGroupLocalDataSource>().buildPersonIdToGroupIds())[person.id] ??
          const <String>[];
  if (!context.mounted) return;
  final groupsLabel = _groupsLabelForPerson(groupIds, allGroups);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _PersonDetailSheetBody(
        person: person,
        groupsLabel: groupsLabel,
        allowEdit: allowEdit,
        parentContext: context,
      );
    },
  );
}

String _groupsLabelForPerson(
  List<String> groupIds,
  List<GroupCollection> groups,
) {
  final byId = {for (final g in groups) g.id: g.name};
  return groupIds
      .map((id) => byId[id] ?? '')
      .where((n) => n.trim().isNotEmpty)
      .join(', ');
}

bool _personIsSyncedToCloud(PersonCollection p) {
  return p.isSynced ||
      (p.driveFaceFileId != null && p.driveFaceFileId!.trim().isNotEmpty);
}

String _fullName(PersonCollection p) {
  final first = (p.firstName ?? '').trim();
  final last = (p.lastName ?? '').trim();
  return [first, last].where((s) => s.isNotEmpty).join(' ');
}

class _PersonDetailSheetBody extends StatelessWidget {
  const _PersonDetailSheetBody({
    required this.person,
    required this.groupsLabel,
    required this.allowEdit,
    required this.parentContext,
  });

  final PersonCollection person;
  final String groupsLabel;
  final bool allowEdit;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final p = person;
    final img = p.faceImagePath;
    final hasImg =
        img != null && img.trim().isNotEmpty && File(img).existsSync();
    final full = _fullName(p);
    final linked = p.linkedUserId != null && p.linkedUserId!.trim().isNotEmpty;
    final email = (p.linkedUserEmail ?? '').trim();
    final notes = p.notes.trim();
    final birth = p.birthDate;

    Widget detailLine(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              value,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final fichaEmpty = groupsLabel.isEmpty &&
        birth == null &&
        email.isEmpty &&
        notes.isEmpty &&
        (p.driveFaceFileId == null || p.driveFaceFileId!.trim().isEmpty);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                  child: hasImg
                      ? ClipOval(
                          child: Image(
                            key: ValueKey<String>(
                              faceImageWidgetCacheKey(img),
                            ),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            image: FileImage(File(img)),
                          ),
                        )
                      : const Icon(Icons.person_outline,
                          size: 44, color: AppTheme.navy),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      if (full.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          full,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      if (linked) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.bolt, size: 18, color: Colors.blue),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('Cuenta LifeTime vinculada'),
                            ),
                          ],
                        ),
                      ],
                      if (_personIsSyncedToCloud(p)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sincronizado',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (allowEdit)
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
                    onPressed: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!parentContext.mounted) return;
                        Navigator.of(parentContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider(
                              create: (_) => sl<PeopleCubit>()..bootstrap(),
                              child: EditPersonPage(person: p),
                            ),
                          ),
                        );
                      });
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (groupsLabel.isNotEmpty)
                    detailLine('Grupos', groupsLabel),
                  if (birth != null)
                    detailLine(
                      'Cumpleaños',
                      '${birth.day.toString().padLeft(2, '0')}/'
                          '${birth.month.toString().padLeft(2, '0')}/'
                          '${birth.year}',
                    ),
                  if (email.isNotEmpty) detailLine('Email', email),
                  if (notes.isNotEmpty) detailLine('Notas', notes),
                  if (fichaEmpty)
                    Text(
                      allowEdit
                          ? 'Pulsa el lápiz para completar la ficha.'
                          : 'Sin datos adicionales en la ficha.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Relaciones',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mapa centrado en ${p.name}. Puedes desplazar y hacer zoom; '
                    'toca un contacto para recentrar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PersonDetailRelationshipTree(personId: p.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
