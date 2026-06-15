import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/notifiers/people_faces_revision_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart'
    show PersonCircleAvatar, faceImageWidgetCacheKey;
import '../../../settings/presentation/widgets/account_settings_widgets.dart';
import '../../../sync/schedule_cloud_sync.dart';

/// Menú dedicado al perfil del usuario local (persona raíz `isMe`).
class LocalUserProfilePage extends StatefulWidget {
  const LocalUserProfilePage({super.key});

  @override
  State<LocalUserProfilePage> createState() => _LocalUserProfilePageState();
}

class _LocalUserProfilePageState extends State<LocalUserProfilePage> {
  PersonCollection? _root;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final root = await sl<IsarPersonDataSource>().getRootUser();
    if (!mounted) return;
    setState(() {
      _root = root;
      _loading = false;
    });
  }

  Future<void> _openEdit() async {
    final root = _root;
    if (root == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => LocalUserProfileEditPage(person: root),
      ),
    );
    if (updated == true) await _load();
  }

  String _displayName(PersonCollection p) {
    final parts = [p.firstName, p.lastName]
        .where((s) => (s ?? '').trim().isNotEmpty)
        .map((s) => s!.trim());
    final legal = parts.join(' ');
    if (legal.isNotEmpty) return legal;
    return p.name.trim().isEmpty ? 'Sin nombre' : p.name.trim();
  }

  String? _birthLabel(PersonCollection p) {
    final d = p.birthDate;
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = _root;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navy))
          : root == null
              ? const Center(child: Text('No se encontró tu perfil local.'))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          PersonCircleAvatar(
                            key: ValueKey<String>(
                              faceImageWidgetCacheKey(root.faceImagePath),
                            ),
                            faceImagePath: root.faceImagePath,
                            diameter: 72,
                            semanticLabel: _displayName(root),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName(root),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                if (_birthLabel(root) != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nacimiento: ${_birthLabel(root)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Datos guardados solo en este dispositivo',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SettingsSectionHeader(label: 'Tu cuenta'),
                    ListTile(
                      leading: const Icon(
                        Icons.badge_outlined,
                        color: AppTheme.navy,
                      ),
                      title: const Text('Datos personales'),
                      subtitle: const Text(
                        'Nombre, apellidos, cumpleaños y foto',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.navy,
                      ),
                      onTap: _openEdit,
                    ),
                  ],
                ),
    );
  }
}

/// Formulario de edición del usuario raíz local.
class LocalUserProfileEditPage extends StatefulWidget {
  const LocalUserProfileEditPage({super.key, required this.person});

  final PersonCollection person;

  @override
  State<LocalUserProfileEditPage> createState() =>
      _LocalUserProfileEditPageState();
}

class _LocalUserProfileEditPageState extends State<LocalUserProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late PersonCollection _person;
  DateTime? _birthDate;
  File? _newPhotoFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _firstNameCtrl = TextEditingController(text: _person.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: _person.lastName ?? '');
    _birthDate = _person.birthDate;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _pickPhoto() async {
    if (_saving) return;
    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final result = await sl<FaceCropperService>().pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        if (failure is! FaceCropCancelledFailure &&
            failure.message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (file) => setState(() => _newPhotoFile = file),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final displayName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    _person
      ..name = displayName.isEmpty ? _person.name : displayName
      ..firstName = firstName.isEmpty ? null : firstName
      ..lastName = lastName.isEmpty ? null : lastName
      ..birthDate = _birthDate
      ..isMe = true;

    try {
      await sl<IsarPersonDataSource>().upsert(_person);
      final photo = _newPhotoFile;
      if (photo != null) {
        await sl<FaceCropperService>().saveForPerson(
          personId: _person.id,
          croppedFile: photo,
        );
      }
      sl<PeopleFacesRevisionNotifier>().bump();
      scheduleCloudDataSync();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthLabel = _birthDate == null
        ? 'Selecciona tu fecha de nacimiento'
        : '${_birthDate!.day.toString().padLeft(2, '0')}/'
            '${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}';
    final photoPath = _person.faceImagePath;
    final previewFile = _newPhotoFile;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(title: const Text('Datos personales')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _pickPhoto,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                    backgroundImage: previewFile != null
                        ? FileImage(previewFile)
                        : (photoPath != null && photoPath.trim().isNotEmpty
                            ? FileImage(File(photoPath))
                            : null),
                    child: previewFile == null &&
                            (photoPath == null || photoPath.trim().isEmpty)
                        ? const Icon(
                            Icons.add_a_photo_outlined,
                            size: 36,
                            color: AppTheme.navy,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _pickPhoto,
                  child: Text(
                    previewFile == null &&
                            (photoPath == null || photoPath.trim().isEmpty)
                        ? 'Añadir foto'
                        : 'Cambiar foto',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.name,
                autofillHints: const [],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Escribe tu nombre.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.name,
                autofillHints: const [],
                decoration: const InputDecoration(
                  labelText: 'Apellidos',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    birthLabel,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
