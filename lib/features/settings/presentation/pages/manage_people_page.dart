import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';
import 'add_person_page.dart';
import 'edit_person_page.dart';

class ManagePeoplePage extends StatelessWidget {
  const ManagePeoplePage({super.key});

  String _fullName(PersonCollection p) {
    final first = (p.firstName ?? '').trim();
    final last = (p.lastName ?? '').trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    return full;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar personas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Añadir persona',
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.cream,
        onPressed: () => _addPerson(context),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: BlocBuilder<PeopleCubit, PeopleState>(
        builder: (context, state) {
          final selectedGroup = ValueNotifier<String>('Todos');
          if (state is PeopleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = (state as PeopleLoaded).people;
          if (people.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: AppTheme.navy.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay personas.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea una ficha para asociarla a hitos con @menciones o al añadir participantes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _addPerson(context),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Añadir persona'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        foregroundColor: AppTheme.cream,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allGroups = <String>{
            for (final p in people)
              if (p.group.trim().isNotEmpty) p.group.trim(),
          }.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final orderedAll = [...people]
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          return ValueListenableBuilder<String>(
            valueListenable: selectedGroup,
            builder: (context, group, _) {
              final filtered = group == 'Todos'
                  ? orderedAll
                  : orderedAll
                      .where((p) => p.group.trim() == group)
                      .toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, color: AppTheme.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: group,
                            items: [
                              const DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos los grupos'),
                              ),
                              ...allGroups.map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                selectedGroup.value = (v ?? 'Todos'),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Grupo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72, endIndent: 16),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final img = p.faceImagePath;
                        final hasImg = img != null &&
                            img.trim().isNotEmpty &&
                            File(img).existsSync();

                        final full = _fullName(p);
                        final linked = p.linkedUserId != null &&
                            p.linkedUserId!.trim().isNotEmpty;

                        return ListTile(
                          onTap: () => _openPersonDetailSheet(context, p),
                          leading: GestureDetector(
                            onTap: () => _assignPhoto(context, p),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppTheme.navy.withValues(alpha: 0.10),
                              child: hasImg
                                  ? ClipOval(
                                      child: Image(
                                        key: ValueKey<String>(
                                          faceImageWidgetCacheKey(img),
                                        ),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                        image: FileImage(File(img)),
                                      ),
                                    )
                                  : const Icon(Icons.person_outline,
                                      color: AppTheme.navy),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (linked)
                                const Icon(
                                  Icons.bolt,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (full.isNotEmpty)
                                Text(
                                  full,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.black54,
                                      ),
                                ),
                              if (p.driveFaceFileId != null &&
                                  p.driveFaceFileId!.trim().isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text('Foto sincronizada en la nube'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openPersonDetailSheet(
    BuildContext parentContext,
    PersonCollection p,
  ) async {
    final theme = Theme.of(parentContext);
    await showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: AppTheme.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        final img = p.faceImagePath;
        final hasImg = img != null &&
            img.trim().isNotEmpty &&
            File(img).existsSync();
        final full = _fullName(p);
        final linked = p.linkedUserId != null &&
            p.linkedUserId!.trim().isNotEmpty;
        final email = (p.linkedUserEmail ?? '').trim();
        final group = p.group.trim();
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

        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.88;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                            Row(
                              children: [
                                const Icon(Icons.bolt,
                                    size: 18, color: Colors.blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Cuenta LifeTime vinculada',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (parentContext.mounted) {
                            _edit(parentContext, p);
                          }
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 28),
                if (group.isNotEmpty) detailLine('Grupo', group),
                if (birth != null)
                  detailLine(
                    'Cumpleaños',
                    '${birth.day.toString().padLeft(2, '0')}/'
                        '${birth.month.toString().padLeft(2, '0')}/${birth.year}',
                  ),
                if (email.isNotEmpty) detailLine('Email', email),
                if (notes.isNotEmpty) detailLine('Notas', notes),
                if (p.driveFaceFileId != null &&
                    p.driveFaceFileId!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Foto de perfil sincronizada en la nube',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                if (group.isEmpty &&
                    birth == null &&
                    email.isEmpty &&
                    notes.isEmpty &&
                    (p.driveFaceFileId == null ||
                        p.driveFaceFileId!.trim().isEmpty))
                  Text(
                    'Pulsa el lápiz para completar la ficha o toca la foto en la lista para asignar imagen.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final cubit = context.read<PeopleCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const AddPersonPage(),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, PersonCollection p) async {
    final cubit = context.read<PeopleCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: EditPersonPage(person: p),
        ),
      ),
    );
  }

  Future<void> _assignPhoto(BuildContext context, PersonCollection p) async {
    final cubit = context.read<PeopleCubit>();
    final faceCropService = sl<FaceCropperService>();

    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !context.mounted) return;

    final cropResult = await faceCropService.pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );

    if (!context.mounted) return;
    await cropResult.fold(
      (failure) async {
        if (failure is! FaceCropCancelledFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      (file) async {
        final saveResult = await cubit.saveCroppedFaceForPerson(
          personId: p.id,
          croppedFile: file,
        );
        if (!context.mounted) return;
        saveResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          ),
          (_) {},
        );
      },
    );
  }
}
