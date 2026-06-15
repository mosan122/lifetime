import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/pages/timeline_page.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';

/// Onboarding 100% local: sustituye al login clásico cuando la nube está
/// desactivada. Crea el nodo raíz ("yo") en Isar y entra a la bitácora.
class LocalOnboardingView extends StatefulWidget {
  const LocalOnboardingView({super.key});

  @override
  State<LocalOnboardingView> createState() => _LocalOnboardingViewState();
}

class _LocalOnboardingViewState extends State<LocalOnboardingView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _birthDate;
  File? _photoFile;
  bool _saving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
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
        if (failure is! FaceCropCancelledFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (file) => setState(() => _photoFile = file),
    );
  }

  Future<void> _start() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final ds = sl<IsarPersonDataSource>();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final displayName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    final person = PersonCollection()
      ..id = const Uuid().v4()
      ..name = displayName
      ..firstName = firstName.isEmpty ? null : firstName
      ..lastName = lastName.isEmpty ? null : lastName
      ..birthDate = _birthDate
      ..isMe = true
      ..isSynced = false;

    try {
      await ds.upsert(person);
      final photo = _photoFile;
      if (photo != null) {
        await sl<FaceCropperService>().saveForPerson(
          personId: person.id,
          croppedFile: photo,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar tu perfil: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const TimelinePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthLabel = _birthDate == null
        ? 'Selecciona tu fecha de nacimiento'
        : _formatDate(_birthDate!);
    final photo = _photoFile;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 56,
                      color: AppTheme.navy.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Bienvenido a LifeTime',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tus datos se quedan en tu dispositivo. No necesitas una '
                      'cuenta ni conexión a internet: tu bitácora es tuya y solo '
                      'tuya, guardada de forma privada y local.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: GestureDetector(
                        onTap: _saving ? null : _pickPhoto,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                          child: photo != null
                              ? ClipOval(
                                  child: Image.file(
                                    photo,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 36,
                                  color: AppTheme.navy,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _pickPhoto,
                        child: Text(
                          photo == null ? 'Añadir foto' : 'Cambiar foto',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.name,
                      autofillHints: const [],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre',
                        hintText: '¿Cómo te llamas?',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Escribe tu nombre para continuar.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.name,
                      autofillHints: const [],
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Tus apellidos',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _start(),
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
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _birthDate == null
                                ? theme.hintColor
                                : AppTheme.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Comenzar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${d.day} de ${months[d.month - 1]} de ${d.year}';
}
