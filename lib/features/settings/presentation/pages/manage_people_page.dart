import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';

class ManagePeoplePage extends StatelessWidget {
  const ManagePeoplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar personas')),
      body: BlocBuilder<PeopleCubit, PeopleState>(
        builder: (context, state) {
          if (state is PeopleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = (state as PeopleLoaded).people;
          if (people.isEmpty) {
            return const Center(
              child: Text('Aún no hay personas.'),
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

  Future<void> _rename(BuildContext context, PersonCollection p) async {
    final ds = sl<IsarPersonDataSource>();
    final cubit = context.read<PeopleCubit>();
    final controller = TextEditingController(text: p.name);
    final newName = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cream,
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text(
              'Guardar',
              style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
