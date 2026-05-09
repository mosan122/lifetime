import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/person_collection.dart';
import 'face_source_bottom_sheet.dart';
import 'person_avatar_badge.dart';

/// Creación rápida de persona (desde hito o desde Personas): apodo obligatorio,
/// nombre, apellidos y foto opcionales.
Future<PersonCollection?> showQuickCreatePersonSheet({
  required BuildContext context,
  required IsarPersonDataSource personDs,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<PersonCollection?>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => QuickCreatePersonForm(
      personDs: personDs,
      showHeaderBar: true,
      title: 'Nueva persona',
      submitLabel: 'Crear y añadir',
      onSubmitted: (context, created) async {
        Navigator.pop(context, created);
      },
    ),
  );
}

/// Formulario compartido: pantalla completa (Ajustes → Personas) o hoja modal (hito).
class QuickCreatePersonForm extends StatefulWidget {
  const QuickCreatePersonForm({
    super.key,
    required this.personDs,
    required this.showHeaderBar,
    required this.title,
    required this.submitLabel,
    required this.onSubmitted,
  });

  final IsarPersonDataSource personDs;
  final bool showHeaderBar;
  final String title;
  final String submitLabel;
  final Future<void> Function(BuildContext context, PersonCollection created)
      onSubmitted;

  @override
  State<QuickCreatePersonForm> createState() => _QuickCreatePersonFormState();
}

class _QuickCreatePersonFormState extends State<QuickCreatePersonForm> {
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  File? _croppedPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  String? _nullIfBlank(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickPhoto() async {
    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final cropResult = await sl<FaceCropperService>().pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );
    if (!mounted) return;
    cropResult.fold(
      (failure) {
        if (failure is! FaceCropCancelledFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      (file) => setState(() => _croppedPhoto = file),
    );
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _saving = true);

    final existing = await widget.personDs.fetchByName(nickname);
    if (!mounted) return;
    if (existing != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una persona con ese apodo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final id = const Uuid().v4();
    final created = PersonCollection()
      ..id = id
      ..name = nickname
      ..firstName = _nullIfBlank(_firstNameCtrl.text)
      ..lastName = _nullIfBlank(_lastNameCtrl.text);

    await widget.personDs.upsert(created);

    if (_croppedPhoto != null) {
      final saveResult = await sl<FaceCropperService>().saveForPerson(
        personId: id,
        croppedFile: _croppedPhoto!,
      );
      if (!mounted) return;
      saveResult.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        },
        (_) {},
      );
    }

    final saved = await widget.personDs.fetchById(id);
    if (!mounted) return;
    setState(() => _saving = false);
    final out = saved ?? created;
    await widget.onSubmitted(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = !_saving && _nicknameCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showHeaderBar)
                Row(
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              if (widget.showHeaderBar) const SizedBox(height: 8),
              TextField(
                controller: _nicknameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre para mostrar (apodo) *',
                  hintText: 'Ej. Ana, Papá',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Apellidos',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto (opcional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PersonCircleAvatar(
                    faceImagePath: _croppedPhoto?.path,
                    diameter: 56,
                    semanticLabel: 'Vista previa',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _croppedPhoto == null
                            ? 'Elegir foto'
                            : 'Cambiar foto',
                      ),
                    ),
                  ),
                  if (_croppedPhoto != null)
                    IconButton(
                      tooltip: 'Quitar foto',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _croppedPhoto = null),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: AppTheme.cream,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
