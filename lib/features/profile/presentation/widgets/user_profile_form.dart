import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_profile_details.dart';

/// Formulario compartido: onboarding y edición de perfil.
class UserProfileForm extends StatefulWidget {
  const UserProfileForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.isBusy = false,
  });

  final UserProfileDetails initial;
  final String submitLabel;
  final Future<void> Function(UserProfileDetails details, Uint8List? avatarBytes)
      onSubmit;
  final bool isBusy;

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

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (x == null) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = b;
    });
  }

  Future<void> _pickBirth() async {
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
    final d = UserProfileDetails(
      userId: widget.initial.userId,
      email: widget.initial.email,
      displayName: _display.text.trim(),
      firstName: _first.text.trim().isEmpty ? null : _first.text.trim(),
      lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
      birthDate: _birth,
      avatarUrl: _pickedBytes == null ? _avatarUrl : null,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 64,
                backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
                backgroundImage: _avatarProvider,
                child: _avatarProvider == null
                    ? Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: AppTheme.navy.withValues(alpha: 0.45),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir otra foto'),
            ),
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
              onPressed: _pickBirth,
            ),
            onTap: _pickBirth,
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
