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
import '../../../milestones/data/datasources/person_group_local_datasource.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';
import '../widgets/edit_person_groups_tab.dart';
import '../widgets/edit_person_relations_tab.dart';

class EditPersonPage extends StatefulWidget {
  const EditPersonPage({super.key, required this.person});
  final PersonCollection person;

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage>
    with SingleTickerProviderStateMixin {
  late PersonCollection _p;
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _emailCtrl;
  DateTime? _birthDate;

  List<String> _selectedGroupIds = [];

  bool _saving = false;
  bool _verifying = false;
  String? _verifiedUserId;
  String? _verifyError;

  late TabController _tabController;

  String get _displayNameForTitle {
    final t = _nicknameCtrl.text.trim();
    return t.isEmpty ? _p.name : t;
  }

  String get _legalNameLine {
    final parts = [
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _p = widget.person;
    _nicknameCtrl = TextEditingController(text: _p.name);
    _firstNameCtrl = TextEditingController(text: _p.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: _p.lastName ?? '');
    _notesCtrl = TextEditingController(text: _p.notes);
    _emailCtrl = TextEditingController(text: _p.linkedUserEmail ?? '');
    _verifiedUserId = _p.linkedUserId;
    _birthDate = _p.birthDate;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroupMembership());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
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

  Future<void> _loadGroupMembership() async {
    if (!sl.isRegistered<PersonGroupLocalDataSource>()) return;
    final ids =
        await sl<PersonGroupLocalDataSource>().groupIdsForPerson(_p.id);
    if (!mounted) return;
    setState(() => _selectedGroupIds = ids);
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

    final updated = _p.copyScalars()
      ..name = nickname
      ..firstName = _nullIfBlank(_firstNameCtrl.text)
      ..lastName = _nullIfBlank(_lastNameCtrl.text)
      ..birthDate = _birthDate
      ..group = ''
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

  Future<void> _confirmDeletePerson() async {
    final label = _displayNameForTitle;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar persona'),
        content: Text(
          'Se borrará «$label» de este dispositivo, sus grupos y relaciones.\n\n'
          'No podrás eliminarla si sigue apareciendo en algún hito.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    final result = await context.read<PeopleCubit>().deletePerson(_p.id);
    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
      (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«$label» eliminada.')),
        );
      },
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

    final updated = _p.copyScalars()
      ..name = nickname
      ..firstName = _nullIfBlank(_firstNameCtrl.text)
      ..lastName = _nullIfBlank(_lastNameCtrl.text)
      ..birthDate = _birthDate
      ..group = ''
      ..notes = _notesCtrl.text
      ..linkedUserEmail = email
      ..linkedUserId = linkedId
      ..faceImagePath = _p.faceImagePath
      ..driveFaceFileId = _p.driveFaceFileId;

    await ds.upsert(updated);
    if (!mounted) return;
    await sl<PersonGroupLocalDataSource>()
        .replacePersonMemberships(_p.id, _selectedGroupIds);
    if (!mounted) return;
    await context.read<PeopleCubit>().reload();
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _nicknameCtrl.text.trim().isNotEmpty;
    final canVerify = !_verifying && _emailCtrl.text.trim().isNotEmpty;
    final premium = sl<PremiumService>().isPremium;

    final peopleState = context.watch<PeopleCubit>().state;
    final allGroups = peopleState is PeopleLoaded
        ? peopleState.groups
        : const <GroupCollection>[];

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _tabController.index == 0
            ? const Text('Editar persona')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayNameForTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _tabController.index == 1
                        ? 'Grupos'
                        : 'Relaciones',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.navy.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.navy,
          unselectedLabelColor: AppTheme.navy.withValues(alpha: 0.45),
          indicatorColor: AppTheme.navy,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Grupos'),
            Tab(text: 'Relaciones'),
          ],
        ),
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
      body: TabBarView(
          controller: _tabController,
          children: [
            ListView(
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
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _confirmDeletePerson,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  label: Text(
                    'Eliminar persona',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
            EditPersonGroupsTab(
              allGroups: allGroups,
              selectedIds: _selectedGroupIds,
              onChanged: (ids) => setState(() => _selectedGroupIds = ids),
            ),
            EditPersonRelationsTab(
              subject: _p,
              displayName: _displayNameForTitle,
              legalName: _legalNameLine,
            ),
          ],
        ),
      );
  }
}

