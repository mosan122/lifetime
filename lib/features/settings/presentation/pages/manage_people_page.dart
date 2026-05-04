import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';

class ManagePeoplePage extends StatefulWidget {
  const ManagePeoplePage({super.key});

  @override
  State<ManagePeoplePage> createState() => _ManagePeoplePageState();
}

class _ManagePeoplePageState extends State<ManagePeoplePage> {
  final _ds = sl<IsarPersonDataSource>();
  final _faceCropService = sl<FaceCropperService>();

  late Future<List<PersonCollection>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    _peopleFuture = _ds.fetchAll();
    unawaited(
      sl<CloudSyncService>().restoreMissingFaces().then((_) {
        if (mounted) setState(() { _peopleFuture = _ds.fetchAll(); });
      }),
    );
  }

  void _reload() => setState(() { _peopleFuture = _ds.fetchAll(); });

  Future<void> _rename(PersonCollection p) async {
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
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
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

    final existing = await _ds.fetchByName(v);
    if (existing != null && existing.id != p.id) {
      if (!mounted) return;
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
    await _ds.upsert(updated);
    if (!mounted) return;
    _reload();
  }

  Future<void> _assignPhoto(PersonCollection p) async {
    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final cropResult = await _faceCropService.pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );

    if (!mounted) return;
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
        final saveResult = await _faceCropService.saveForPerson(
          personId: p.id,
          croppedFile: file,
        );
        if (!mounted) return;
        saveResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          ),
          (_) => _reload(),
        );
      },
    );
  }

  Future<void> _clearPhoto(PersonCollection p) async {
    final driveId = p.driveFaceFileId;
    final updated = PersonCollection()
      ..isarId = p.isarId
      ..id = p.id
      ..name = p.name
      ..faceImagePath = null
      ..driveFaceFileId = null;
    await _ds.upsert(updated);
    if (driveId != null) {
      unawaited(sl<CloudSyncService>().deleteDriveFace(driveId));
    }
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar personas')),
      body: FutureBuilder<List<PersonCollection>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          final people = snapshot.data ?? const <PersonCollection>[];
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
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (context, index) {
              final p = ordered[index];
              final img = p.faceImagePath;
              final hasImg = img != null && img.trim().isNotEmpty && File(img).existsSync();

              return ListTile(
                leading: GestureDetector(
                  onTap: () => _assignPhoto(p),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                    backgroundImage: hasImg ? FileImage(File(img!)) : null,
                    child: hasImg ? null : const Icon(Icons.person_outline, color: AppTheme.navy),
                  ),
                ),
                title: Text(p.name),
                subtitle: (p.driveFaceFileId != null && p.driveFaceFileId!.trim().isNotEmpty)
                    ? const Text('Foto sincronizada en la nube')
                    : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'assign_photo') await _assignPhoto(p);
                    if (value == 'rename') await _rename(p);
                    if (value == 'clear_photo') await _clearPhoto(p);
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
}

