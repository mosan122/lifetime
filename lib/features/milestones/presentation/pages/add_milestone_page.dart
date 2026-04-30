import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/create_milestone_cubit.dart';
import '../bloc/edit_milestone_cubit.dart';

const _kSpanishMonths = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class AddMilestonePage extends StatelessWidget {
  final Milestone? initial;

  const AddMilestonePage({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    if (initial != null) {
      return BlocProvider(
        create: (_) => sl<EditMilestoneCubit>(),
        child: _EditMilestoneView(milestone: initial!),
      );
    }
    return BlocProvider(
      create: (_) => sl<CreateMilestoneCubit>(),
      child: const _CreateMilestoneView(),
    );
  }
}

// ── Create mode ───────────────────────────────────────────────────────────────

class _CreateMilestoneView extends StatefulWidget {
  const _CreateMilestoneView();

  @override
  State<_CreateMilestoneView> createState() => _CreateMilestoneViewState();
}

class _CreateMilestoneViewState extends State<_CreateMilestoneView> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();
  final List<_SelectedMedia> _selectedMedia = [];
  LocationData? _locationData;
  bool _fetchingLocation = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationAsync();
  }

  Future<void> _fetchLocationAsync() async {
    final data = await sl<LocationService>().fetchLocation();
    if (mounted) {
      setState(() {
        _locationData = data;
        _fetchingLocation = false;
        if (data?.placeName != null) {
          _locationController.text = data!.placeName!;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    setState(() {
      for (final x in files) {
        _selectedMedia.add(_SelectedMedia(file: File(x.path), type: MediaType.image));
      }
    });
  }

  Future<void> _pickVideo() async {
    final xFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;
    setState(() {
      _selectedMedia.add(_SelectedMedia(file: File(xFile.path), type: MediaType.video));
    });
  }

  void _removeMediaAt(int index) {
    setState(() => _selectedMedia.removeAt(index));
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _submit(BuildContext context) {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;

    String? accessToken;
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      accessToken = authState.user.accessToken;
    }

    final title = _titleController.text.trim();
    final locationText = _locationController.text.trim();
    context.read<CreateMilestoneCubit>().submit(
          title: title.isEmpty ? null : title,
          userNote: note,
          eventDate: _selectedDate,
          mediaFiles: _selectedMedia.map((e) => e.file).toList(),
          mediaTypes: _selectedMedia.map((e) => e.type).toList(),
          accessToken: accessToken,
          locationName: locationText.isEmpty ? null : locationText,
          latitude: _locationData?.latitude,
          longitude: _locationData?.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CreateMilestoneCubit, CreateMilestoneState>(
      listener: (context, state) {
        if (state is CreateMilestoneSuccess) {
          Navigator.pop(context, true);
        }
        if (state is CreateMilestoneError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is CreateMilestoneSubmitting;
        final step = isSubmitting ? state.step : null;

        return SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: const SizedBox.shrink(),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            body: LayoutBuilder(
              builder: (context, viewportConstraints) {
                final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          16 + keyboardInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _titleController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              style: theme.textTheme.bodyLarge,
                              decoration: _textFieldDecoration(
                                theme,
                                'Título (opcional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TextField(
                                controller: _noteController,
                                minLines: 8,
                                maxLines: null,
                                autofocus: true,
                                enabled: !isSubmitting,
                                keyboardType: TextInputType.multiline,
                                textAlignVertical: TextAlignVertical.top,
                                style: theme.textTheme.bodyLarge,
                                decoration: _cleanMultilineDecoration(
                                  theme,
                                  hintText: 'Escribe lo que quieres recordar...',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _MediaPickerSection(
                              selected: _selectedMedia,
                              isSubmitting: isSubmitting,
                              onPickImages: _pickImages,
                              onPickVideo: _pickVideo,
                              onRemoveAt: _removeMediaAt,
                            ),
                            const SizedBox(height: 8),
                            _DatePickerRow(
                              selectedDate: _selectedDate,
                              enabled: !isSubmitting,
                              onTap: () => _pickDate(context),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              enabled: !isSubmitting,
                              style: theme.textTheme.bodyMedium,
                              decoration: _locationFieldDecoration(
                                theme,
                                hintText: _fetchingLocation
                                    ? 'Detectando ubicación...'
                                    : 'Lugar (opcional)',
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (step != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppTheme.navy),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(step, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _noteController,
                              builder: (context, value, _) {
                                final hasText = value.text.trim().isNotEmpty;
                                return _SubmitButton(
                                  label: 'Guardar',
                                  isSubmitting: isSubmitting,
                                  enabled: hasText,
                                  onPressed: () => _submit(context),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ── Edit mode ─────────────────────────────────────────────────────────────────

class _EditMilestoneView extends StatefulWidget {
  final Milestone milestone;
  const _EditMilestoneView({required this.milestone});

  @override
  State<_EditMilestoneView> createState() => _EditMilestoneViewState();
}

class _EditMilestoneViewState extends State<_EditMilestoneView> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.milestone.title);
    _descController =
        TextEditingController(text: widget.milestone.description ?? '');
    _locationController =
        TextEditingController(text: widget.milestone.locationName ?? '');
    _selectedDate = widget.milestone.eventDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _submit(BuildContext context) {
    final desc = _descController.text.trim();
    if (desc.isEmpty) return;
    final locationText = _locationController.text.trim();
    final title = _titleController.text.trim();
    context.read<EditMilestoneCubit>().submit(
          id: widget.milestone.id,
          title: title,
          description: desc,
          eventDate: _selectedDate,
          locationName: locationText.isEmpty ? null : locationText,
          latitude: widget.milestone.latitude,
          longitude: widget.milestone.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<EditMilestoneCubit, EditMilestoneState>(
      listener: (context, state) {
        if (state is EditMilestoneSuccess) {
          Navigator.pop(context, true);
        }
        if (state is EditMilestoneError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is EditMilestoneSubmitting;

        return SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: const SizedBox.shrink(),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            body: LayoutBuilder(
              builder: (context, viewportConstraints) {
                final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          16 + keyboardInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _titleController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              style: theme.textTheme.bodyLarge,
                              decoration: _textFieldDecoration(
                                theme,
                                'Título',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TextField(
                                controller: _descController,
                                minLines: 8,
                                maxLines: null,
                                enabled: !isSubmitting,
                                keyboardType: TextInputType.multiline,
                                textAlignVertical: TextAlignVertical.top,
                                style: theme.textTheme.bodyLarge,
                                decoration: _cleanMultilineDecoration(theme),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DatePickerRow(
                              selectedDate: _selectedDate,
                              enabled: !isSubmitting,
                              onTap: () => _pickDate(context),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              enabled: !isSubmitting,
                              style: theme.textTheme.bodyMedium,
                              decoration: _locationFieldDecoration(
                                theme,
                                hintText: 'Lugar (opcional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _descController,
                              builder: (context, value, _) {
                                final hasText = value.text.trim().isNotEmpty;
                                return _SubmitButton(
                                  label: 'Actualizar',
                                  isSubmitting: isSubmitting,
                                  enabled: hasText,
                                  onPressed: () => _submit(context),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

InputDecoration _textFieldDecoration(ThemeData theme, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: theme.textTheme.bodyLarge?.copyWith(
      color: const Color(0xFFAAAAAA),
    ),
    filled: true,
    fillColor: const Color(0xFFFAFAE8),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppTheme.navy, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
  );
}

InputDecoration _cleanMultilineDecoration(
  ThemeData theme, {
  String? hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: theme.textTheme.bodyLarge?.copyWith(
      color: const Color(0xFFAAAAAA),
    ),
    filled: true,
    fillColor: const Color(0xFFFAFAE8),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}

InputDecoration _locationFieldDecoration(
  ThemeData theme, {
  required String hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle:
        theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFAAAAAA)),
    prefixIcon:
        const Icon(Icons.location_on_outlined, color: AppTheme.navy, size: 20),
    filled: true,
    fillColor: const Color(0xFFFAFAE8),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppTheme.navy, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool isSubmitting;
  final bool enabled;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.isSubmitting,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.navy.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: isSubmitting || !enabled ? null : onPressed,
        child: isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Date picker row ───────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final DateTime selectedDate;
  final bool enabled;
  final VoidCallback onTap;

  const _DatePickerRow({
    required this.selectedDate,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        '${selectedDate.day} de ${_kSpanishMonths[selectedDate.month - 1]} '
        'de ${selectedDate.year}';
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAE8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppTheme.navy),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppTheme.navy),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.navy.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Image picker section ──────────────────────────────────────────────────────

class _SelectedMedia {
  final File file;
  final MediaType type;
  const _SelectedMedia({required this.file, required this.type});
}

class _MediaPickerSection extends StatelessWidget {
  final List<_SelectedMedia> selected;
  final bool isSubmitting;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final void Function(int index) onRemoveAt;

  const _MediaPickerSection({
    required this.selected,
    required this.isSubmitting,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onPickImages,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Fotos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onPickVideo,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Vídeo'),
              ),
            ),
          ],
        ),
        if (selected.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Puedes añadir varias fotos y vídeos (opcional).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.navy.withValues(alpha: 0.7)),
          ),
        ] else ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selected.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = selected[index];
                return _MediaPreviewTile(
                  file: item.file,
                  type: item.type,
                  enabled: !isSubmitting,
                  onRemove: () => onRemoveAt(index),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  final File file;
  final MediaType type;
  final bool enabled;
  final VoidCallback onRemove;

  const _MediaPreviewTile({
    required this.file,
    required this.type,
    required this.enabled,
    required this.onRemove,
  });

  Future<Uint8List?> _videoThumbBytes() async {
    return VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 50,
      maxHeight: 160,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final base = ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAE8),
          borderRadius: borderRadius,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: type == MediaType.image
            ? Image.file(file, fit: BoxFit.cover)
            : FutureBuilder<Uint8List?>(
                future: _videoThumbBytes(),
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes == null && snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (bytes == null) {
                    return Container(
                      color: const Color(0xFFFAFAE8),
                      child: const Center(
                        child: Icon(Icons.videocam_outlined, color: AppTheme.navy),
                      ),
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes, fit: BoxFit.cover),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );

    return Stack(
      children: [
        base,
        if (enabled)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
