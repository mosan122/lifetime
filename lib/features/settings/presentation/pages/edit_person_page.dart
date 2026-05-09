import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';

class EditPersonPage extends StatefulWidget {
  const EditPersonPage({super.key, required this.person});
  final PersonCollection person;

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage> {
  late PersonCollection _p;
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _emailCtrl;
  DateTime? _birthDate;

  bool _saving = false;
  bool _verifying = false;
  String? _verifiedUserId;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _p = widget.person;
    _nicknameCtrl = TextEditingController(text: _p.name);
    _firstNameCtrl = TextEditingController(text: _p.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: _p.lastName ?? '');
    _groupCtrl = TextEditingController(text: _p.group);
    _notesCtrl = TextEditingController(text: _p.notes);
    _emailCtrl = TextEditingController(text: _p.linkedUserEmail ?? '');
    _verifiedUserId = _p.linkedUserId;
    _birthDate = _p.birthDate;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _groupCtrl.dispose();
    _notesCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _nullIfBlank(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _refreshPersonFromDb() async {
    final fresh = await sl<IsarPersonDataSource>().fetchById(_p.id);
    if (!mounted) return;
    if (fresh != null) setState(() => _p = fresh);
  }

  Future<void> _assignPhoto() async {
    if (_saving) return;
    final cubit = context.read<PeopleCubit>();
    final faceCropService = sl<FaceCropperService>();

    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final cropResult = await faceCropService.pickAndCrop(
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
        final saveResult = await cubit.saveCroppedFaceForPerson(
          personId: _p.id,
          croppedFile: file,
        );
        if (!mounted) return;
        await saveResult.fold<Future<void>>(
          (failure) async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message),
                backgroundColor: Colors.red.shade700,
              ),
            );
          },
          (_) async {
            await _refreshPersonFromDb();
          },
        );
      },
    );
  }

  Future<void> _clearPhoto() async {
    if (_saving) return;
    final ds = sl<IsarPersonDataSource>();
    final cubit = context.read<PeopleCubit>();
    final driveId = _p.driveFaceFileId;

    final email = _nullIfBlank(_emailCtrl.text)?.toLowerCase();
    final prevEmail = (_p.linkedUserEmail ?? '').trim().toLowerCase();
    String? linkedId;
    if (_verifiedUserId != null) {
      linkedId = _verifiedUserId;
    } else if (email != null && email == prevEmail) {
      linkedId = _p.linkedUserId;
    }

    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica un apodo antes de quitar la foto.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updated = PersonCollection()
      ..isarId = _p.isarId
      ..id = _p.id
      ..name = nickname
      ..firstName = _nullIfBlank(_firstNameCtrl.text)
      ..lastName = _nullIfBlank(_lastNameCtrl.text)
      ..birthDate = _birthDate
      ..group = _groupCtrl.text.trim()
      ..notes = _notesCtrl.text
      ..linkedUserEmail = email
      ..linkedUserId = linkedId
      ..faceImagePath = null
      ..driveFaceFileId = null;
    await ds.upsert(updated);
    if (driveId != null) {
      unawaited(sl<CloudSyncService>().deleteDriveFace(driveId));
    }
    if (!mounted) return;
    await cubit.reload();
    await _refreshPersonFromDb();
  }

  Widget _buildProfileAvatar() {
    final img = _p.faceImagePath;
    final hasImg =
        img != null && img.trim().isNotEmpty && File(img).existsSync();
    if (!hasImg) {
      return const Icon(
        Icons.person_outline,
        size: 40,
        color: AppTheme.navy,
      );
    }
    return ClipOval(
      child: Image(
        key: ValueKey<String>(faceImageWidgetCacheKey(img)),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        image: FileImage(File(img)),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    final email = _emailCtrl.text.trim();
    setState(() {
      _verifying = true;
      _verifyError = null;
      _verifiedUserId = null;
    });

    final result = await context.read<PeopleCubit>().verifyLifeTimeEmail(email);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _verifyError = failure.message;
        _verifiedUserId = null;
        _verifying = false;
      }),
      (id) => setState(() {
        _verifiedUserId = id;
        _verifyError = null;
        _verifying = false;
      }),
    );
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _saving = true);

    final ds = sl<IsarPersonDataSource>();
    final existing = await ds.fetchByName(nickname);
    if (!mounted) return;
    if (existing != null && existing.id != _p.id) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una persona con ese apodo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final email = _nullIfBlank(_emailCtrl.text)?.toLowerCase();
    final prevEmail = (_p.linkedUserEmail ?? '').trim().toLowerCase();
    String? linkedId;
    if (_verifiedUserId != null) {
      linkedId = _verifiedUserId;
    } else if (email != null && email == prevEmail) {
      linkedId = _p.linkedUserId;
    }

    final updated = PersonCollection()
      ..isarId = _p.isarId
      ..id = _p.id
      ..name = nickname
      ..firstName = _nullIfBlank(_firstNameCtrl.text)
      ..lastName = _nullIfBlank(_lastNameCtrl.text)
      ..birthDate = _birthDate
      ..group = _groupCtrl.text.trim()
      ..notes = _notesCtrl.text
      ..linkedUserEmail = email
      ..linkedUserId = linkedId
      ..faceImagePath = _p.faceImagePath
      ..driveFaceFileId = _p.driveFaceFileId;

    await ds.upsert(updated);
    if (!mounted) return;
    await context.read<PeopleCubit>().reload();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _nicknameCtrl.text.trim().isNotEmpty;
    final canVerify = !_verifying && _emailCtrl.text.trim().isNotEmpty;
    final premium = sl<PremiumService>().isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar persona'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Foto de perfil',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _saving ? null : _assignPhoto,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                  child: _buildProfileAvatar(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _assignPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                      label: const Text('Cambiar foto'),
                    ),
                    if ((_p.faceImagePath ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _saving ? null : _clearPhoto,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Quitar foto'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Apodo *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _firstNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Apellidos'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined, color: AppTheme.navy),
            title: const Text('Cumpleaños'),
            subtitle: Text(
              _birthDate == null
                  ? 'Sin fecha'
                  : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
            ),
            trailing: TextButton(
              onPressed: _pickBirthDate,
              child: const Text('Elegir'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _groupCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Grupo',
              hintText: 'Ej. Familia',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Notas',
              hintText: 'Detalles importantes, relación, etc.',
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email (opcional)',
              helperText: premium
                  ? null
                  : 'La verificación con cuenta LifeTime está disponible con Premium.',
              suffixIcon: _verifiedUserId != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            onChanged: (_) => setState(() {
              _verifiedUserId = null;
              _verifyError = null;
            }),
          ),
          if (premium) ...[
            const SizedBox(height: 16),
            Text(
              'Vincular con usuario de LifeTime',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: AppTheme.cream,
              ),
              onPressed: canVerify ? _verifyEmail : null,
              icon: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Verificar email'),
            ),
            if (_verifyError != null) ...[
              const SizedBox(height: 8),
              Text(
                _verifyError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            if (_verifiedUserId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Vinculado correctamente.',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

