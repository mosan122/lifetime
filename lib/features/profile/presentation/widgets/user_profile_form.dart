import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../domain/entities/user_profile_details.dart';

/// Formulario compartido: onboarding y edición de perfil.
/// Misma UX que personas: hoja cámara/galería + recorte circular.
class UserProfileForm extends StatefulWidget {
  const UserProfileForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.isBusy = false,
    this.shrinkWrap = false,
  });

  final UserProfileDetails initial;
  final String submitLabel;
  final Future<void> Function(UserProfileDetails details, Uint8List? avatarBytes)
      onSubmit;
  final bool isBusy;

  /// Si es true, el formulario no hace scroll propio (útil dentro de un [ListView] padre).
  final bool shrinkWrap;

  @override
  State<UserProfileForm> createState() => _UserProfileFormState();
}

class _UserProfileFormState extends State<UserProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _display;
  late final TextEditingController _first;
  late final TextEditingController _last;
  DateTime? _birth;
  Uint8List? _pickedBytes;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _display = TextEditingController(text: widget.initial.displayName);
    _first = TextEditingController(text: widget.initial.firstName ?? '');
    _last = TextEditingController(text: widget.initial.lastName ?? '');
    _birth = widget.initial.birthDate;
    _avatarUrl = widget.initial.avatarUrl;
  }

  @override
  void dispose() {
    _display.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _hasAvatar =>
      _pickedBytes != null ||
      ((_avatarUrl ?? '').trim().isNotEmpty);

  Future<void> _assignPhoto() async {
    if (widget.isBusy) return;
    final cropper = sl<FaceCropperService>();

    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !mounted) return;

    final cropResult = await cropper.pickAndCrop(
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
        final b = await file.readAsBytes();
        if (!mounted) return;
        setState(() => _pickedBytes = b);
      },
    );
  }

  void _clearPhoto() {
    if (widget.isBusy) return;
    setState(() {
      _pickedBytes = null;
      _avatarUrl = null;
    });
  }

  Future<void> _pickBirth() async {
    if (widget.isBusy) return;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('es', 'ES'),
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Mantener URL remota previa si hay bytes nuevos: si la subida falla, no se pierde el avatar en BD.
    final d = UserProfileDetails(
      userId: widget.initial.userId,
      email: widget.initial.email,
      displayName: _display.text.trim(),
      firstName: _first.text.trim().isEmpty ? null : _first.text.trim(),
      lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
      birthDate: _birth,
      avatarUrl: _avatarUrl,
      isPremium: widget.initial.isPremium,
    );
    await widget.onSubmit(d, _pickedBytes);
  }

  ImageProvider<Object>? get _avatarProvider {
    if (_pickedBytes != null) {
      return MemoryImage(_pickedBytes!);
    }
    final u = _avatarUrl;
    if (u != null && u.isNotEmpty) {
      return NetworkImage(u);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text(
            'Foto de perfil',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: widget.isBusy ? null : _assignPhoto,
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
                  backgroundImage: _avatarProvider,
                  child: _avatarProvider == null
                      ? Icon(
                          Icons.person_outline,
                          size: 40,
                          color: AppTheme.navy.withValues(alpha: 0.45),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.isBusy ? null : _assignPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                      label: const Text('Cambiar foto'),
                    ),
                    if (_hasAvatar) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.isBusy ? null : _clearPhoto,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Quitar foto'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _display,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Apodo (visible)',
              hintText: 'Cómo quieres que te llamemos',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'El apodo es obligatorio';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Apellidos (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha de nacimiento'),
            subtitle: Text(
              _birth == null
                  ? 'Opcional · no seleccionada'
                  : '${_birth!.day}/${_birth!.month}/${_birth!.year}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: widget.isBusy ? null : () => _pickBirth(),
            ),
            onTap: widget.isBusy ? null : () => _pickBirth(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: widget.isBusy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
              ),
              child: widget.isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
