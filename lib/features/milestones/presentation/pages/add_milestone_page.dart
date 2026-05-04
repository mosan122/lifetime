import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/utils/milestone_title_utils.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/create_milestone_cubit.dart';
import '../bloc/edit_milestone_cubit.dart';
import '../../data/datasources/isar_category_datasource.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/category_collection.dart';
import '../../data/models/local/media_item_embed.dart';
import '../../data/models/local/person_collection.dart';
import '../widgets/face_source_bottom_sheet.dart';
import '../widgets/milestone_participant_picker_sheet.dart';
import '../widgets/person_avatar_badge.dart';

int _clampGalleryCoverIndexForCount(int coverIndex, int mediaCount) {
  if (mediaCount <= 0) return 0;
  return coverIndex.clamp(0, mediaCount - 1);
}

/// Píxeles máximos al decodificar una imagen para miniatura (~92 lógicos).
/// Evita decodificar a tamaño completo en la UI (mucho más rápido con varias fotos).
int mediaPreviewDecodeExtentPx(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (184 * dpr).round().clamp(256, 960);
}

int _adjustGalleryCoverAfterRemove({
  required int cover,
  required int removedGlobalIndex,
  required int oldTotalCount,
}) {
  final newLen = oldTotalCount - 1;
  if (newLen <= 0) return 0;
  var c = cover;
  if (removedGlobalIndex < c) {
    c--;
  } else if (removedGlobalIndex == c) {
    c = c.clamp(0, newLen - 1);
  }
  return c.clamp(0, newLen - 1);
}

const _kSpanishMonths = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Título cuando el usuario deja el campo en blanco al editar (creación usa
/// [milestoneFallbackTitleFromDescription] en el repositorio con la misma regla).
String milestoneTitleFromDescription(String description) =>
    milestoneFallbackTitleFromDescription(description);

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
  final List<PersonCollection> _participants = [];
  final _faceCropService = sl<FaceCropperService>();
  final _personDs = sl<IsarPersonDataSource>();
  DateTime _selectedDate = DateTime.now();
  int _categoryId = 1;
  final List<_SelectedMedia> _selectedMedia = [];
  LocationData? _locationData;
  bool _fetchingLocation = true;
  int? _importingImagesTotal;
  int _importingImagesDone = 0;

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
    final files = await _picker.pickMultiImage(imageQuality: 72);
    if (files.isEmpty || !mounted) return;
    final n = files.length;
    if (n == 1) {
      setState(() {
        _selectedMedia.add(
          _SelectedMedia(file: File(files.first.path), type: MediaType.image),
        );
      });
      return;
    }
    setState(() {
      _importingImagesTotal = n;
      _importingImagesDone = 0;
    });
    try {
      for (var i = 0; i < n; i++) {
        if (!mounted) return;
        setState(() {
          _selectedMedia.add(
            _SelectedMedia(file: File(files[i].path), type: MediaType.image),
          );
          _importingImagesDone = i + 1;
        });
        if (i < n - 1) await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importingImagesTotal = null;
          _importingImagesDone = 0;
        });
      }
    }
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

  Future<void> _addParticipant() async {
    if (!mounted) return;
    final picked = await showMilestoneParticipantPickerSheet(
      context: context,
      existingParticipantIds: {for (final p in _participants) p.id},
      personDs: _personDs,
    );
    if (picked != null && mounted) {
      if (_participants.any((x) => x.id == picked.id)) return;
      setState(() => _participants.add(picked));
    }
  }

  List<MediaItemEmbed> _milestoneImageEmbedsForFacePicker() {
    return _selectedMedia
        .where((m) => m.type == MediaType.image)
        .map((m) => MediaItemEmbed()
          ..localPath = m.file.path
          ..thumbnailPath = m.file.path
          ..mediaType = MediaType.image)
        .toList();
  }

  Future<void> _assignParticipantPhoto(PersonCollection p) async {
    final mediaItems = _milestoneImageEmbedsForFacePicker();

    if (!mounted) return;
    final selection = await showFaceSourceBottomSheet(
      context: context,
      milestoneMediaItems: mediaItems.isEmpty ? null : mediaItems,
    );
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
          (updatedPerson) {
            setState(() {
              final idx = _participants.indexWhere((x) => x.id == p.id);
              if (idx != -1) {
                _participants[idx] = PersonCollection()
                  ..isarId = p.isarId
                  ..id = p.id
                  ..name = p.name
                  ..faceImagePath = updatedPerson.faceImagePath
                  ..driveFaceFileId = p.driveFaceFileId;
              }
            });
          },
        );
      },
    );
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
          categoryId: _categoryId,
          mediaFiles: _selectedMedia.map((e) => e.file).toList(),
          mediaTypes: _selectedMedia.map((e) => e.type).toList(),
          accessToken: accessToken,
          locationName: locationText.isEmpty ? null : locationText,
          latitude: _locationData?.latitude,
          longitude: _locationData?.longitude,
          participants: _participants.map((p) => p.id).toList(),
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
                              textCapitalization: TextCapitalization.sentences,
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
                                textCapitalization: TextCapitalization.sentences,
                                textAlignVertical: TextAlignVertical.top,
                                style: theme.textTheme.bodyLarge,
                                decoration: _cleanMultilineDecoration(
                                  theme,
                                  hintText: 'Escribe lo que quieres recordar...',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CategorySelector(
                              value: _categoryId,
                              enabled: !isSubmitting,
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                            const SizedBox(height: 16),
                            _MediaPickerSection(
                              selected: _selectedMedia,
                              isSubmitting: isSubmitting,
                              importImagesTotal: _importingImagesTotal,
                              importImagesDone: _importingImagesDone,
                              onPickImages: _pickImages,
                              onPickVideo: _pickVideo,
                              onRemoveAt: _removeMediaAt,
                            ),
                            const SizedBox(height: 8),
                            _ParticipantsSection(
                              participants: _participants,
                              enabled: !isSubmitting,
                              onAdd: _addParticipant,
                              onAssignPhoto: _assignParticipantPhoto,
                              onRemove: (p) => setState(
                                () => _participants
                                    .removeWhere((x) => x.id == p.id),
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
  late int _categoryId;

  final List<PersonCollection> _participants = [];
  final List<_SelectedMedia> _newMedia = [];
  late List<MediaItem> _existingMedia;
  late int _galleryCoverIndex;
  int? _importingImagesTotal;
  int _importingImagesDone = 0;
  final _picker = ImagePicker();
  final _personDs = sl<IsarPersonDataSource>();
  final _faceCropService = sl<FaceCropperService>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.milestone.title);
    _descController =
        TextEditingController(text: widget.milestone.description ?? '');
    _locationController =
        TextEditingController(text: widget.milestone.locationName ?? '');
    _selectedDate = widget.milestone.eventDate;
    _categoryId = widget.milestone.categoryId;
    _existingMedia = List.from(widget.milestone.mediaItems);
    _galleryCoverIndex = _clampGalleryCoverIndexForCount(
      widget.milestone.galleryCoverIndex,
      _existingMedia.length,
    );
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    final ids = widget.milestone.participantIds;
    if (ids.isEmpty) return;
    final loaded = await _personDs.fetchByIds(ids);
    if (!mounted) return;
    final byId = {for (final p in loaded) p.id: p};
    setState(() {
      _participants
        ..clear()
        ..addAll(ids.map((id) => byId[id]).whereType<PersonCollection>());
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 72);
    if (files.isEmpty || !mounted) return;
    final n = files.length;
    if (n == 1) {
      setState(() {
        _newMedia.add(
          _SelectedMedia(file: File(files.first.path), type: MediaType.image),
        );
      });
      return;
    }
    setState(() {
      _importingImagesTotal = n;
      _importingImagesDone = 0;
    });
    try {
      for (var i = 0; i < n; i++) {
        if (!mounted) return;
        setState(() {
          _newMedia.add(
            _SelectedMedia(file: File(files[i].path), type: MediaType.image),
          );
          _importingImagesDone = i + 1;
        });
        if (i < n - 1) await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importingImagesTotal = null;
          _importingImagesDone = 0;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final xFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;
    setState(() {
      _newMedia.add(_SelectedMedia(file: File(xFile.path), type: MediaType.video));
    });
  }

  int get _totalEditMediaCount => _existingMedia.length + _newMedia.length;

  void _removeExistingMediaAt(int index) {
    setState(() {
      final oldTotal = _totalEditMediaCount;
      _existingMedia.removeAt(index);
      _galleryCoverIndex = _adjustGalleryCoverAfterRemove(
        cover: _galleryCoverIndex,
        removedGlobalIndex: index,
        oldTotalCount: oldTotal,
      );
    });
  }

  void _removeNewMediaAt(int index) {
    setState(() {
      final globalIndex = _existingMedia.length + index;
      final oldTotal = _totalEditMediaCount;
      _newMedia.removeAt(index);
      _galleryCoverIndex = _adjustGalleryCoverAfterRemove(
        cover: _galleryCoverIndex,
        removedGlobalIndex: globalIndex,
        oldTotalCount: oldTotal,
      );
    });
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

  Future<void> _addParticipant() async {
    if (!mounted) return;
    final picked = await showMilestoneParticipantPickerSheet(
      context: context,
      existingParticipantIds: {for (final p in _participants) p.id},
      personDs: _personDs,
    );
    if (picked != null && mounted) {
      if (_participants.any((x) => x.id == picked.id)) return;
      setState(() => _participants.add(picked));
    }
  }

  List<MediaItemEmbed> _milestoneImageEmbedsForFacePicker() {
    final existingEmbeds = _existingMedia
        .where((m) => m.mediaType == MediaType.image)
        .map((m) => MediaItemEmbed()
          ..localPath = m.localPath
          ..thumbnailPath = m.thumbnailPath
          ..mediaType = MediaType.image)
        .toList();
    final newEmbeds = _newMedia
        .where((m) => m.type == MediaType.image)
        .map((m) => MediaItemEmbed()
          ..localPath = m.file.path
          ..thumbnailPath = m.file.path
          ..mediaType = MediaType.image)
        .toList();
    return [...existingEmbeds, ...newEmbeds];
  }

  Future<void> _assignParticipantPhoto(PersonCollection p) async {
    final allEmbeds = _milestoneImageEmbedsForFacePicker();

    if (!mounted) return;
    final selection = await showFaceSourceBottomSheet(
      context: context,
      milestoneMediaItems: allEmbeds.isEmpty ? null : allEmbeds,
    );
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
          (updatedPerson) {
            setState(() {
              final idx = _participants.indexWhere((x) => x.id == p.id);
              if (idx != -1) {
                _participants[idx] = PersonCollection()
                  ..isarId = p.isarId
                  ..id = p.id
                  ..name = p.name
                  ..faceImagePath = updatedPerson.faceImagePath
                  ..driveFaceFileId = p.driveFaceFileId;
              }
            });
          },
        );
      },
    );
  }

  void _submit(BuildContext context) {
    final desc = _descController.text.trim();
    if (desc.isEmpty) return;
    final locationText = _locationController.text.trim();
    final titleInput = _titleController.text.trim();
    final title = titleInput.isEmpty
        ? milestoneTitleFromDescription(desc)
        : titleInput;
    final totalMedia = _totalEditMediaCount;
    final cover = _clampGalleryCoverIndexForCount(
      _galleryCoverIndex,
      totalMedia,
    );
    context.read<EditMilestoneCubit>().submit(
          id: widget.milestone.id,
          title: title,
          description: desc,
          categoryId: _categoryId,
          eventDate: _selectedDate,
          locationName: locationText.isEmpty ? null : locationText,
          latitude: widget.milestone.latitude,
          longitude: widget.milestone.longitude,
          participantIds: _participants.map((p) => p.id).toList(),
          mediaToKeep: List.from(_existingMedia),
          newMediaFiles: _newMedia.map((m) => m.file).toList(),
          newMediaTypes: _newMedia.map((m) => m.type).toList(),
          galleryCoverIndex: cover,
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
                              textCapitalization: TextCapitalization.sentences,
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
                                textCapitalization: TextCapitalization.sentences,
                                textAlignVertical: TextAlignVertical.top,
                                style: theme.textTheme.bodyLarge,
                                decoration: _cleanMultilineDecoration(theme),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CategorySelector(
                              value: _categoryId,
                              enabled: !isSubmitting,
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                            const SizedBox(height: 8),
                            _EditMediaSection(
                              existingMedia: _existingMedia,
                              newMedia: _newMedia,
                              galleryCoverIndex: _galleryCoverIndex,
                              onSetGalleryCover: (i) {
                                if (isSubmitting) return;
                                setState(() {
                                  _galleryCoverIndex =
                                      _clampGalleryCoverIndexForCount(
                                    i,
                                    _totalEditMediaCount,
                                  );
                                });
                              },
                              isSubmitting: isSubmitting,
                              importImagesTotal: _importingImagesTotal,
                              importImagesDone: _importingImagesDone,
                              onPickImages: _pickImages,
                              onPickVideo: _pickVideo,
                              onRemoveExisting: _removeExistingMediaAt,
                              onRemoveNew: _removeNewMediaAt,
                            ),
                            const SizedBox(height: 8),
                            _ParticipantsSection(
                              participants: _participants,
                              enabled: !isSubmitting,
                              onAdd: _addParticipant,
                              onAssignPhoto: _assignParticipantPhoto,
                              onRemove: (p) => setState(
                                () => _participants
                                    .removeWhere((x) => x.id == p.id),
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

class _CategorySelector extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _CategorySelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ds = sl<IsarCategoryDataSource>();

    return FutureBuilder<List<CategoryCollection>>(
      future: ds.fetchAll(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CategoryCollection>[];
        final hasData = snapshot.hasData;

        final safeValue = items.any((c) => c.id == value) ? value : 1;

        return DropdownButtonFormField<int>(
          initialValue: hasData ? safeValue : null,
          items: items
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                ),
              )
              .toList(),
          onChanged: !enabled || !hasData ? null : (v) => onChanged(v ?? 1),
          decoration: InputDecoration(
            labelText: 'Categoría',
            filled: true,
            fillColor: const Color(0xFFFAFAE8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
        );
      },
    );
  }
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
  final int? importImagesTotal;
  final int importImagesDone;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final void Function(int index) onRemoveAt;

  const _MediaPickerSection({
    required this.selected,
    required this.isSubmitting,
    this.importImagesTotal,
    this.importImagesDone = 0,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final importing = importImagesTotal != null;
    final busy = isSubmitting || importing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPickImages,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Fotos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPickVideo,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Vídeo'),
              ),
            ),
          ],
        ),
        if (importing && importImagesTotal! > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Preparando vistas previas '
            '(${importImagesDone.clamp(0, importImagesTotal!)}/$importImagesTotal)…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.navy.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: importImagesDone / importImagesTotal!,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: AppTheme.navy,
            backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
          ),
        ],
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < selected.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    _MediaPreviewTile(
                      file: selected[index].file,
                      type: selected[index].type,
                      enabled: !busy,
                      onRemove: () => onRemoveAt(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  final List<PersonCollection> participants;
  final bool enabled;
  final Future<void> Function()? onAdd;
  final ValueChanged<PersonCollection> onAssignPhoto;
  final ValueChanged<PersonCollection> onRemove;

  const _ParticipantsSection({
    required this.participants,
    required this.enabled,
    required this.onAdd,
    required this.onAssignPhoto,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: participants.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: participants.map((p) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PersonAvatarBadge(
                          faceImagePath: p.faceImagePath,
                          personName: p.name,
                          onAssignPhoto:
                              enabled ? () => onAssignPhoto(p) : () {},
                        ),
                        if (enabled)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onRemove(p),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
        ),
        IconButton(
          onPressed: enabled ? () => onAdd?.call() : null,
          icon: const Icon(Icons.person_add_outlined),
          color: AppTheme.navy,
          tooltip: 'Añadir persona',
        ),
      ],
    );
  }
}

// ── Edit mode media section ───────────────────────────────────────────────────

class _EditMediaSection extends StatelessWidget {
  final List<MediaItem> existingMedia;
  final List<_SelectedMedia> newMedia;
  final int galleryCoverIndex;
  final ValueChanged<int> onSetGalleryCover;
  final bool isSubmitting;
  final int? importImagesTotal;
  final int importImagesDone;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final void Function(int index) onRemoveExisting;
  final void Function(int index) onRemoveNew;

  const _EditMediaSection({
    required this.existingMedia,
    required this.newMedia,
    required this.galleryCoverIndex,
    required this.onSetGalleryCover,
    required this.isSubmitting,
    this.importImagesTotal,
    this.importImagesDone = 0,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasItems = existingMedia.isNotEmpty || newMedia.isNotEmpty;
    final importing = importImagesTotal != null;
    final busy = isSubmitting || importing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPickImages,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Fotos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPickVideo,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Vídeo'),
              ),
            ),
          ],
        ),
        if (importing && importImagesTotal! > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Preparando vistas previas '
            '(${importImagesDone.clamp(0, importImagesTotal!)}/$importImagesTotal)…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.navy.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: importImagesDone / importImagesTotal!,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: AppTheme.navy,
            backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
          ),
        ],
        if (!hasItems) ...[
          const SizedBox(height: 10),
          Text(
            'Puedes añadir varias fotos y vídeos (opcional).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.navy.withValues(alpha: 0.7)),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'El pin indica la imagen del timeline.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.navy.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < existingMedia.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _ExistingMediaTile(
                      item: existingMedia[i],
                      enabled: !busy,
                      onRemove: () => onRemoveExisting(i),
                      isGalleryCover: i == galleryCoverIndex,
                      onPickAsGalleryCover: () => onSetGalleryCover(i),
                    ),
                  ],
                  for (var i = 0; i < newMedia.length; i++) ...[
                    if (i > 0 || existingMedia.isNotEmpty) const SizedBox(width: 10),
                    _MediaPreviewTile(
                      file: newMedia[i].file,
                      type: newMedia[i].type,
                      enabled: !busy,
                      onRemove: () => onRemoveNew(i),
                      isGalleryCover:
                          existingMedia.length + i == galleryCoverIndex,
                      onPickAsGalleryCover: () =>
                          onSetGalleryCover(existingMedia.length + i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExistingMediaTile extends StatelessWidget {
  final MediaItem item;
  final bool enabled;
  final VoidCallback onRemove;
  final bool isGalleryCover;
  final VoidCallback? onPickAsGalleryCover;

  const _ExistingMediaTile({
    required this.item,
    required this.enabled,
    required this.onRemove,
    this.isGalleryCover = false,
    this.onPickAsGalleryCover,
  });

  Future<Uint8List?> _videoThumbBytes() async {
    return VideoThumbnail.thumbnailData(
      video: item.localPath,
      imageFormat: ImageFormat.JPEG,
      quality: 45,
      maxWidth: 200,
      maxHeight: 200,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final file = File(item.localPath);
    final decodePx = mediaPreviewDecodeExtentPx(context);

    Widget content;
    if (item.mediaType == MediaType.image) {
      content = file.existsSync()
          ? Image.file(
              file,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: decodePx,
              cacheHeight: decodePx,
            )
          : Container(
              color: const Color(0xFFFAFAE8),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: AppTheme.navy),
              ),
            );
    } else {
      content = FutureBuilder<Uint8List?>(
        future: _videoThumbBytes(),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null &&
              snap.connectionState != ConnectionState.done) {
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
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
              ),
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
      );
    }

    final theme = Theme.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAE8),
              borderRadius: borderRadius,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: content,
          ),
        ),
        if (isGalleryCover)
          Positioned(
            left: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  'Timeline',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.cream,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (onPickAsGalleryCover != null && enabled)
          Positioned(
            bottom: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPickAsGalleryCover,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isGalleryCover ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                    color: isGalleryCover ? AppTheme.cream : Colors.white,
                  ),
                ),
              ),
            ),
          ),
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

class _MediaPreviewTile extends StatelessWidget {
  final File file;
  final MediaType type;
  final bool enabled;
  final VoidCallback onRemove;
  final bool isGalleryCover;
  final VoidCallback? onPickAsGalleryCover;

  const _MediaPreviewTile({
    required this.file,
    required this.type,
    required this.enabled,
    required this.onRemove,
    this.isGalleryCover = false,
    this.onPickAsGalleryCover,
  });

  Future<Uint8List?> _videoThumbBytes() async {
    return VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 45,
      maxWidth: 200,
      maxHeight: 200,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final decodePx = mediaPreviewDecodeExtentPx(context);
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
            ? Image.file(
                file,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
              )
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
                      Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        cacheWidth: decodePx,
                        cacheHeight: decodePx,
                      ),
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

    final theme = Theme.of(context);
    return Stack(
      children: [
        base,
        if (isGalleryCover)
          Positioned(
            left: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  'Timeline',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.cream,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (onPickAsGalleryCover != null && enabled)
          Positioned(
            bottom: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPickAsGalleryCover,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isGalleryCover ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                    color: isGalleryCover ? AppTheme.cream : Colors.white,
                  ),
                ),
              ),
            ),
          ),
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
