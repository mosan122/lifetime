import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../../../milestones/presentation/widgets/person_name_alert_dialog.dart';
import '../bloc/people_cubit.dart';

class ManagePeoplePage extends StatelessWidget {
  const ManagePeoplePage({super.key});

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

          final ordered = [...people]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: ordered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (context, index) {
              final p = ordered[index];
              final img = p.faceImagePath;
              final hasImg =
                  img != null && img.trim().isNotEmpty && File(img).existsSync();

              return ListTile(
                leading: GestureDetector(
                  onTap: () => _assignPhoto(context, p),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
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
                        : const Icon(Icons.person_outline, color: AppTheme.navy),
                  ),
                ),
                title: Text(p.name),
                subtitle: (p.driveFaceFileId != null &&
                        p.driveFaceFileId!.trim().isNotEmpty)
                    ? const Text('Foto sincronizada en la nube')
                    : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'assign_photo') await _assignPhoto(context, p);
                    if (value == 'rename') await _rename(context, p);
                    if (value == 'clear_photo') await _clearPhoto(context, p);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'assign_photo',
                      child: Text('Asignar foto de perfil'),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Cambiar nombre'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_photo',
                      child: Text('Borrar foto de perfil'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final ds = sl<IsarPersonDataSource>();
    final cubit = context.read<PeopleCubit>();
    final newName = await showPersonNameAlertDialog(
      context: context,
      title: 'Nueva persona',
      hintText: 'Nombre',
      submitLabel: 'Crear',
      textCapitalization: TextCapitalization.words,
    );

    final v = (newName ?? '').trim();
    if (v.isEmpty) return;

    final existing = await ds.fetchByName(v);
    if (existing != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una persona con ese nombre.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final created = PersonCollection()
      ..id = const Uuid().v4()
      ..name = v;
    await ds.upsert(created);
    if (!context.mounted) return;
    await cubit.reload();
  }

  Future<void> _rename(BuildContext context, PersonCollection p) async {
    final ds = sl<IsarPersonDataSource>();
    final cubit = context.read<PeopleCubit>();
    final newName = await showPersonNameAlertDialog(
      context: context,
      title: 'Cambiar nombre',
      initialValue: p.name,
      hintText: 'Nombre',
      submitLabel: 'Guardar',
    );

    final v = (newName ?? '').trim();
    if (v.isEmpty || v == p.name) return;

    final existing = await ds.fetchByName(v);
    if (existing != null && existing.id != p.id) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una persona con ese nombre.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updated = PersonCollection()
      ..isarId = p.isarId
      ..id = p.id
      ..name = v
      ..faceImagePath = p.faceImagePath
      ..driveFaceFileId = p.driveFaceFileId;
    await ds.upsert(updated);
    if (!context.mounted) return;
    await cubit.reload();
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

  Future<void> _clearPhoto(BuildContext context, PersonCollection p) async {
    final ds = sl<IsarPersonDataSource>();
    final cubit = context.read<PeopleCubit>();
    final driveId = p.driveFaceFileId;
    final updated = PersonCollection()
      ..isarId = p.isarId
      ..id = p.id
      ..name = p.name
      ..faceImagePath = null
      ..driveFaceFileId = null;
    await ds.upsert(updated);
    if (driveId != null) {
      unawaited(sl<CloudSyncService>().deleteDriveFace(driveId));
    }
    if (!context.mounted) return;
    await cubit.reload();
  }
}
