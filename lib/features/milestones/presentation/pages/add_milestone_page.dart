import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/services/place_autocomplete_service.dart';
import '../../../../core/models/milestone_location_data.dart';
import '../../../../core/utils/milestone_title_utils.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/milestone_categories.dart';
import '../../../../core/exceptions/duplicate_saved_location_name_exception.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../milestones/data/datasources/isar_category_datasource.dart';
import '../../../milestones/data/datasources/isar_saved_location_datasource.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../profile/data/datasources/user_profile_local_datasource.dart';
import '../../../profile/domain/entities/user_profile_details.dart';
import '../bloc/create_milestone_cubit.dart';
import '../bloc/edit_milestone_cubit.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/media_item_embed.dart';
import '../../data/models/local/person_collection.dart';
import '../../data/models/local/category_collection.dart';
import '../../data/models/local/saved_location_collection.dart';
import '../widgets/face_source_bottom_sheet.dart';
import '../widgets/milestone_participant_picker_sheet.dart';
import '../widgets/person_avatar_badge.dart';
import '../widgets/person_name_alert_dialog.dart';
import '../../../sync/schedule_cloud_sync.dart';
import 'location_picker_page.dart';

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
  final _picker = ImagePicker();
  final List<PersonCollection> _participants = [];
  final Set<String> _protagonistIds = {};
  final _faceCropService = sl<FaceCropperService>();
  final _personDs = sl<IsarPersonDataSource>();
  final _milestoneDs = sl<IsarMilestoneDataSource>();
  final _placeAutocomplete = PlaceAutocompleteService();
  DateTime _selectedDate = DateTime.now();
  String _categoryId = 'otros';
  List<CategoryCollection> _categories = const [];
  bool _loadingCategories = true;
  final List<_SelectedMedia> _selectedMedia = [];
  MilestoneLocationData? _pickedPlace;
  int? _savedLocationId;
  bool _savePlaceToMyPlaces = false;
  int? _importingImagesTotal;
  int _importingImagesDone = 0;

  @override
  void initState() {
    super.initState();
    _fetchLocationAsync();
    _loadCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSelfFromProfile());
  }

  Future<void> _loadCategories() async {
    try {
      final ds = sl<IsarCategoryDataSource>();
      await ds.ensureSeeded();
      final cats = await ds.fetchAll();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
      // Ensure selected id exists.
      if (_categories.isNotEmpty &&
          !_categories.any((c) => c.id == _categoryId)) {
        setState(() => _categoryId = _categories.first.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _maybeSavePickedPlace() async {
    // Legacy safety: favorite saving is now handled in the picker.
  }

  Future<void> _fetchLocationAsync() async {
    final data = await sl<LocationService>().fetchLocation();
    if (mounted) {
      setState(() {
        if (data?.placeName != null && _pickedPlace == null) {
          _pickedPlace = MilestoneLocationData(
            name: data!.placeName!,
            latitude: data.latitude,
            longitude: data.longitude,
          );
        }
      });
    }
  }

  /// Añade al usuario actual como participante (y protagonista) según perfil Isar / Person vinculada.
  Future<void> _bootstrapSelfFromProfile() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return;
    final userId = auth.user.id.trim();
    if (userId.isEmpty || !mounted) return;

    final profile = await sl<UserProfileLocalDataSource>().getByUserId(userId);
    var me = await _personDs.fetchByLinkedUserId(userId);
    me ??= await _createSelfPersonFromLinkedAccount(
      userId: userId,
      email: auth.user.email,
      profile: profile,
    );
    if (me == null || !mounted) return;
    me = await _hydrateSelfParticipantFace(me, profile, userId);
    if (!mounted) return;
    final self = me;
    if (_participants.any((p) => p.id == self.id)) return;
    setState(() {
      _participants.add(self);
      _protagonistIds.add(self.id);
    });
  }

  /// Persona Isar vinculada a la cuenta; solo si hay fila en [UserProfileCollection] vía [profile].
  Future<PersonCollection?> _createSelfPersonFromLinkedAccount({
    required String userId,
    required String email,
    required UserProfileDetails? profile,
  }) async {
    if (profile == null) return null;
    final nickname = profile.displayName.trim();
    if (nickname.isEmpty) return null;
    final id = const Uuid().v4();
    final c = PersonCollection()
      ..id = id
      ..name = nickname
      ..firstName = profile.firstName
      ..lastName = profile.lastName
      ..birthDate = profile.birthDate
      ..linkedUserId = userId
      ..linkedUserEmail =
          email.trim().isEmpty ? null : email.trim().toLowerCase();
    return _personDs.upsert(c);
  }

  /// Copia el avatar del perfil (ruta local Isar o URL) a `faces/{personId}.jpg`.
  Future<PersonCollection> _hydrateSelfParticipantFace(
    PersonCollection person,
    UserProfileDetails? profile,
    String userId,
  ) async {
    final existing = await _personDs.fetchById(person.id);
    if (existing == null) return person;
    final fp = existing.faceImagePath?.trim();
    if (fp != null && fp.isNotEmpty && File(fp).existsSync()) {
      return existing;
    }

    final profileLocal = sl<UserProfileLocalDataSource>();
    final localSrc = await profileLocal.getLocalAvatarPath(userId);
    final remote = profile?.avatarUrl?.trim() ?? '';

    final appDir = await getApplicationDocumentsDirectory();
    final facesDir = Directory('${appDir.path}/faces');
    if (!facesDir.existsSync()) await facesDir.create(recursive: true);
    final destPath = '${facesDir.path}/${existing.id}.jpg';

    try {
      if (localSrc != null &&
          localSrc.isNotEmpty &&
          File(localSrc).existsSync()) {
        await File(localSrc).copy(destPath);
        if (localSrc != destPath) {
          await profileLocal.patchLocalAvatarPath(userId, destPath);
        }
      } else if (remote.isNotEmpty) {
        final uri = Uri.tryParse(remote);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
          return existing;
        }
        final res = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 ||
            res.statusCode >= 300 ||
            res.bodyBytes.isEmpty) {
          return existing;
        }
        await File(destPath).writeAsBytes(res.bodyBytes, flush: true);
        await profileLocal.patchLocalAvatarPath(userId, destPath);
      } else {
        return existing;
      }
    } catch (_) {
      return existing;
    }

    PaintingBinding.instance.imageCache.evict(FileImage(File(destPath)));

    final updated = existing.copyScalars()
      ..faceImagePath = destPath
      ..driveFaceFileId = existing.driveFaceFileId;
    return _personDs.upsert(updated);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
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
      milestoneDs: _milestoneDs,
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
                _participants[idx] = p.copyScalars()
                  ..faceImagePath = updatedPerson.faceImagePath
                  ..driveFaceFileId = updatedPerson.driveFaceFileId;
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

    final title = _titleController.text.trim();
    final picked = _pickedPlace;
    final usePicked = picked != null;
    final coordsLat = usePicked ? picked.latitude : null;
    final coordsLon = usePicked ? picked.longitude : null;
    context.read<CreateMilestoneCubit>().submit(
          title: title.isEmpty ? null : title,
          userNote: note,
          eventDate: _selectedDate,
          categoryId: _categoryId,
          mediaFiles: _selectedMedia.map((e) => e.file).toList(),
          mediaTypes: _selectedMedia.map((e) => e.type).toList(),
          savedLocationId: _savedLocationId,
          locationName: usePicked ? picked.name.trim() : null,
          locationCity: usePicked ? picked.city : null,
          locationCountry: usePicked ? picked.country : null,
          latitude: coordsLat,
          longitude: coordsLon,
          participants: _participants.map((p) => p.id).toList(),
          protagonistIds: _protagonistIds
              .where((id) => _participants.any((p) => p.id == id))
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CreateMilestoneCubit, CreateMilestoneState>(
      listener: (context, state) {
        if (state is CreateMilestoneSuccess) {
          _maybeSavePickedPlace();
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
                            const SizedBox(height: 14),
                            _CategorySelector(
                              categories: _categories,
                              value: _categoryId,
                              enabled: !isSubmitting && !_loadingCategories,
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                            const SizedBox(height: 8),
                            _ParticipantsSection(
                              participants: _participants,
                              protagonistIds: _protagonistIds,
                              enabled: !isSubmitting,
                              onAdd: _addParticipant,
                              onAssignPhoto: _assignParticipantPhoto,
                              onToggleProtagonist: (p) => setState(() {
                                if (_protagonistIds.contains(p.id)) {
                                  _protagonistIds.remove(p.id);
                                } else {
                                  _protagonistIds.add(p.id);
                                }
                              }),
                              onRemove: (p) => setState(
                                () {
                                  _participants.removeWhere((x) => x.id == p.id);
                                  _protagonistIds.remove(p.id);
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            _MilestoneLocationRow(
                              value: _pickedPlace,
                              enabled: !isSubmitting,
                              onTap: () async {
                                final initialQuery =
                                    _pickedPlace?.name.trim() ?? '';
                                final result = await showPlacePickerSheet(
                                  context: context,
                                  initialQuery: initialQuery,
                                  service: _placeAutocomplete,
                                );
                                if (!context.mounted) return;
                                if (result != null) {
                                  setState(() {
                                    _pickedPlace = result.place;
                                    _savedLocationId = result.savedLocationId;
                                    _savePlaceToMyPlaces = false;
                                  });
                                }
                              },
                              onClear: () => setState(() {
                                _pickedPlace = null;
                                _savedLocationId = null;
                                _savePlaceToMyPlaces = false;
                              }),
                            ),
                            const SizedBox(height: 8),
                            _DatePickerRow(
                              selectedDate: _selectedDate,
                              enabled: !isSubmitting,
                              onTap: () => _pickDate(context),
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
  late DateTime _selectedDate;
  late String _categoryId;
  List<CategoryCollection> _categories = const [];
  bool _loadingCategories = true;
  MilestoneLocationData? _pickedPlace;
  int? _savedLocationId;
  bool _savePlaceToMyPlaces = false;
  final _placeAutocomplete = PlaceAutocompleteService();
  late final String _initialLocationText;
  late final double? _initialLat;
  late final double? _initialLon;
  late final String? _initialCity;
  late final String? _initialCountry;

  final List<PersonCollection> _participants = [];
  final Set<String> _protagonistIds = {};
  final List<_SelectedMedia> _newMedia = [];
  late List<MediaItem> _existingMedia;
  late int _galleryCoverIndex;
  int? _importingImagesTotal;
  int _importingImagesDone = 0;
  final _picker = ImagePicker();
  final _personDs = sl<IsarPersonDataSource>();
  final _milestoneDs = sl<IsarMilestoneDataSource>();
  final _faceCropService = sl<FaceCropperService>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.milestone.title);
    _descController =
        TextEditingController(text: widget.milestone.description ?? '');
    _initialLocationText = (widget.milestone.locationName ?? '').trim();
    _savedLocationId = widget.milestone.savedLocationId;
    _initialLat = widget.milestone.latitude;
    _initialLon = widget.milestone.longitude;
    _initialCity = widget.milestone.locationCity;
    _initialCountry = widget.milestone.locationCountry;
    _selectedDate = widget.milestone.eventDate;
    _categoryId = (widget.milestone.categoryId ?? 'otros').trim().isEmpty
        ? 'otros'
        : widget.milestone.categoryId!.trim().toLowerCase();
    _existingMedia = List.from(widget.milestone.mediaItems);
    _galleryCoverIndex = _clampGalleryCoverIndexForCount(
      widget.milestone.galleryCoverIndex,
      _existingMedia.length,
    );
    _loadCategories();
    _loadParticipants();
    _protagonistIds
      ..clear()
      ..addAll(widget.milestone.protagonistIds);

    final existingName = (widget.milestone.locationName ?? '').trim();
    if (existingName.isNotEmpty &&
        widget.milestone.latitude != null &&
        widget.milestone.longitude != null) {
      _pickedPlace = MilestoneLocationData(
        name: existingName,
        latitude: widget.milestone.latitude,
        longitude: widget.milestone.longitude,
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final ds = sl<IsarCategoryDataSource>();
      await ds.ensureSeeded();
      final cats = await ds.fetchAll();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
      if (_categories.isNotEmpty &&
          !_categories.any((c) => c.id == _categoryId)) {
        setState(() => _categoryId = _categories.first.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _maybeSavePickedPlace() async {
    // Legacy safety: favorite saving is now handled in the picker.
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
      milestoneDs: _milestoneDs,
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
                _participants[idx] = p.copyScalars()
                  ..faceImagePath = updatedPerson.faceImagePath
                  ..driveFaceFileId = updatedPerson.driveFaceFileId;
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
    final picked = _pickedPlace;
    final usePicked = picked != null;
    final keepExistingLink = picked == null &&
        _initialLat != null &&
        _initialLon != null &&
        _initialLocationText.isNotEmpty;
    final coordsLat =
        usePicked ? picked.latitude : (keepExistingLink ? _initialLat : null);
    final coordsLon =
        usePicked ? picked.longitude : (keepExistingLink ? _initialLon : null);
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
          savedLocationId: _savedLocationId,
          locationName: usePicked
              ? picked.name.trim()
              : keepExistingLink
                  ? _initialLocationText
                  : null,
          locationCity: usePicked
              ? picked.city
              : keepExistingLink
                  ? _initialCity
                  : null,
          locationCountry: usePicked
              ? picked.country
              : keepExistingLink
                  ? _initialCountry
                  : null,
          latitude: coordsLat,
          longitude: coordsLon,
          participantIds: _participants.map((p) => p.id).toList(),
          protagonistIds: _protagonistIds
              .where((id) => _participants.any((p) => p.id == id))
              .toList(),
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
          _maybeSavePickedPlace();
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
                            const SizedBox(height: 14),
                            _CategorySelector(
                              categories: _categories,
                              value: _categoryId,
                              enabled: !isSubmitting && !_loadingCategories,
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                            const SizedBox(height: 8),
                            _ParticipantsSection(
                              participants: _participants,
                              protagonistIds: _protagonistIds,
                              enabled: !isSubmitting,
                              onAdd: _addParticipant,
                              onAssignPhoto: _assignParticipantPhoto,
                              onToggleProtagonist: (p) => setState(() {
                                if (_protagonistIds.contains(p.id)) {
                                  _protagonistIds.remove(p.id);
                                } else {
                                  _protagonistIds.add(p.id);
                                }
                              }),
                              onRemove: (p) => setState(
                                () {
                                  _participants.removeWhere((x) => x.id == p.id);
                                  _protagonistIds.remove(p.id);
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            _MilestoneLocationRow(
                              value: _pickedPlace ??
                                  (_initialLocationText.isNotEmpty
                                      ? MilestoneLocationData(
                                          name: _initialLocationText,
                                          city: _initialCity,
                                          country: _initialCountry,
                                          latitude: _initialLat,
                                          longitude: _initialLon,
                                        )
                                      : null),
                              enabled: !isSubmitting,
                              onTap: () async {
                                final initialQuery = (_pickedPlace?.name ??
                                        _initialLocationText)
                                    .trim();
                                final result = await showPlacePickerSheet(
                                  context: context,
                                  initialQuery: initialQuery,
                                  service: _placeAutocomplete,
                                );
                                if (!context.mounted) return;
                                if (result != null) {
                                  setState(() {
                                    _pickedPlace = result.place;
                                    _savedLocationId = result.savedLocationId;
                                    _savePlaceToMyPlaces = false;
                                  });
                                }
                              },
                              onClear: () => setState(() {
                                _pickedPlace = null;
                                _savedLocationId = null;
                                _savePlaceToMyPlaces = false;
                              }),
                            ),
                            const SizedBox(height: 8),
                            _DatePickerRow(
                              selectedDate: _selectedDate,
                              enabled: !isSubmitting,
                              onTap: () => _pickDate(context),
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

// Nota: el “Lugar” ya no se edita con TextField en el formulario principal.
// Se gestiona con el icono de ubicación (junto a personas) + chip bajo el título.

class PlacePickerResult {
  final MilestoneLocationData place;
  final int? savedLocationId;
  const PlacePickerResult({required this.place, this.savedLocationId});
}

Future<PlacePickerResult?> showPlacePickerSheet({
  required BuildContext context,
  required String initialQuery,
  required PlaceAutocompleteService service,
}) {
  return showModalBottomSheet<PlacePickerResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _PlacePickerSheet(
      initialQuery: initialQuery,
      service: service,
    ),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  final String initialQuery;
  final PlaceAutocompleteService service;
  const _PlacePickerSheet({
    required this.initialQuery,
    required this.service,
  });

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  late final TextEditingController _ctrl;
  List<MilestoneLocationData> _items = const [];
  List<SavedLocationCollection> _saved = const [];
  List<MilestoneLocationData> _recents = const [];
  bool _loading = false;
  String? _error;
  int _reqId = 0;
  String _lastQuery = '';
  bool _saveToMyPlaces = false;
  MilestoneLocationData? _selected;
  int? _selectedSavedLocationId;
  bool _savedExpanded = false;
  String? _geocodeAddressForSave;

  Future<int?> _maybePersistToMyPlaces(
    MilestoneLocationData picked, {
    int? existingIsarId,
    String? geocodeAddress,
  }) async {
    if (!_saveToMyPlaces) return null;
    final name = picked.name.trim();
    if (name.isEmpty) return null;
    try {
      final ds = sl<IsarSavedLocationDataSource>();
      SavedLocationCollection? existing;
      if (existingIsarId != null) {
        existing = await ds.fetchById(existingIsarId);
      }
      final c = SavedLocationCollection()
        ..name = name
        ..address = (geocodeAddress ?? '').trim().isEmpty
            ? null
            : geocodeAddress!.trim()
        ..city = (picked.city ?? '').trim().isEmpty ? null : picked.city!.trim()
        ..country = (picked.country ?? '').trim().isEmpty
            ? null
            : picked.country!.trim()
        ..latitude = picked.latitude
        ..longitude = picked.longitude;
      if (existing != null) {
        c
          ..isarId = existing.isarId
          ..clientId = existing.clientId;
      }
      final saved = await ds.upsert(c);
      scheduleCloudDataSync();
      await _loadSaved();
      return saved.isarId;
    } on DuplicateSavedLocationNameException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el lugar: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
    return null;
  }

  Future<MilestoneLocationData?> _promptFriendlyPlaceName(
    MilestoneLocationData picked,
  ) async {
    if (!_saveToMyPlaces) return picked;
    _geocodeAddressForSave = picked.name.trim();
    final friendly = await showPersonNameAlertDialog(
      context: context,
      title: 'Nombre del lugar',
      initialValue: picked.name,
      hintText: 'Nombre amigable',
      submitLabel: 'Guardar',
      textCapitalization: TextCapitalization.sentences,
      useRootNavigator: true,
    );
    final name = (friendly ?? '').trim();
    if (name.isEmpty) return picked;
    return MilestoneLocationData(
      name: name,
      city: picked.city,
      country: picked.country,
      latitude: picked.latitude,
      longitude: picked.longitude,
    );
  }

  /// Guarda en «Mis lugares» si la estrella está activa y hay selección.
  Future<void> _persistSelectionIfSaving() async {
    if (!_saveToMyPlaces) return;
    final base = _selected;
    if (base == null) return;

    final named = await _promptFriendlyPlaceName(base);
    if (!mounted || named == null) return;

    final savedId = await _maybePersistToMyPlaces(
      named,
      existingIsarId: _selectedSavedLocationId,
      geocodeAddress: _geocodeAddressForSave,
    );
    if (!mounted) return;

    setState(() {
      _selected = named;
      if (savedId != null) _selectedSavedLocationId = savedId;
      _savedExpanded = true;
      _ctrl.text = named.name;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
    if (savedId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${named.name}» guardado en Mis lugares'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _loadSaved();
    _loadRecents();
    _search(widget.initialQuery);
    _ctrl.addListener(() => _search(_ctrl.text));
  }

  Future<void> _loadSaved() async {
    try {
      final ds = sl<IsarSavedLocationDataSource>();
      final items = await ds.fetchAll();
      if (!mounted) return;
      setState(() {
        _saved = items.where((e) => e.name.trim().isNotEmpty).toList();
        if (_saved.isNotEmpty) _savedExpanded = true;
      });
    } catch (_) {
      // Ignore: saved places are best-effort.
    }
  }

  Future<void> _loadRecents() async {
    try {
      final ds = sl<IsarMilestoneDataSource>();
      final recents = await ds.fetchRecentLocations(limit: 8);
      if (!mounted) return;
      setState(() {
        _recents = recents
            .map(
              (e) => MilestoneLocationData(
                name: (e.name ?? '').trim(),
                city: e.city,
                country: e.country,
                latitude: e.latitude,
                longitude: e.longitude,
              ),
            )
            .where((e) => e.name.trim().isNotEmpty)
            .toList();
      });
    } catch (_) {
      // Ignore: recents are best-effort.
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Conserva coordenadas de [_selected] aunque el usuario edite el nombre en el campo.
  MilestoneLocationData _resolvePickedForAccept(String q) {
    final query = q.trim();
    final base = _selected;
    if (base != null) {
      if (query.isEmpty) return base;
      return MilestoneLocationData(
        name: query,
        city: base.city,
        country: base.country,
        latitude: base.latitude,
        longitude: base.longitude,
      );
    }
    if (query.isEmpty) {
      return const MilestoneLocationData(name: '');
    }
    final match = _findLocationMatchForQuery(query);
    return match ?? MilestoneLocationData(name: query);
  }

  MilestoneLocationData? _findLocationMatchForQuery(String query) {
    final qLower = query.toLowerCase();
    bool nameMatches(MilestoneLocationData l) =>
        l.name.trim().toLowerCase() == qLower;

    for (final s in _saved) {
      if (nameMatches(
        MilestoneLocationData(
          name: s.name,
          city: s.city,
          country: s.country,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      )) {
        return MilestoneLocationData(
          name: query,
          city: s.city,
          country: s.country,
          latitude: s.latitude,
          longitude: s.longitude,
        );
      }
    }
    for (final r in _recents) {
      if (nameMatches(r)) {
        return MilestoneLocationData(
          name: query,
          city: r.city,
          country: r.country,
          latitude: r.latitude,
          longitude: r.longitude,
        );
      }
    }
    for (final i in _items) {
      if (nameMatches(i)) {
        return MilestoneLocationData(
          name: query,
          city: i.city,
          country: i.country,
          latitude: i.latitude,
          longitude: i.longitude,
        );
      }
    }
    return null;
  }

  void _search(String q) {
    final query = q.trim();
    _lastQuery = query;
    if (query.isEmpty) {
      _reqId++;
      setState(() {
        _items = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    // Debounce simple.
    final myId = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    Future<void>.delayed(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      if (myId != _reqId) return; // stale
      if (query != _lastQuery) return;
      try {
        final res = await widget.service.search(query);
        if (!mounted) return;
        if (myId != _reqId) return; // stale
        setState(() {
          _items = res;
          _loading = false;
          _error = null;
        });
      } catch (_) {
        if (!mounted) return;
        if (myId != _reqId) return; // stale
        setState(() {
          _items = const [];
          _loading = false;
          _error =
              'No se pudo buscar lugares ahora mismo. Revisa tu conexión e inténtalo de nuevo.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final q = _ctrl.text.trim();
    final qLower = q.toLowerCase();

    bool matchesQuerySaved(SavedLocationCollection l) {
      if (qLower.isEmpty) return true;
      final hay = <String>[
        l.name,
        l.city ?? '',
        l.country ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(qLower);
    }

    bool matchesQuery(MilestoneLocationData l) {
      if (qLower.isEmpty) return true;
      final hay = <String>[
        l.name,
        l.city ?? '',
        l.country ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(qLower);
    }

    final savedFiltered = _saved.where(matchesQuerySaved).toList();
    final recentsFiltered = _recents.where(matchesQuery).toList();
    final showSaved = savedFiltered.isNotEmpty;
    final savedExpandedEffective = qLower.isNotEmpty || _savedExpanded;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Buscar lugar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Escribe una ciudad, lugar o dirección…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Aceptar',
                icon: const Icon(Icons.check),
                onPressed: (_selected == null && q.isEmpty)
                    ? null
                    : () async {
                        var picked = _resolvePickedForAccept(q);
                        if (_saveToMyPlaces) {
                          final named = await _promptFriendlyPlaceName(picked);
                          if (!context.mounted) return;
                          picked = named ?? picked;
                        }

                        final savedId = await _maybePersistToMyPlaces(
                          picked,
                          existingIsarId: _selectedSavedLocationId,
                          geocodeAddress: _geocodeAddressForSave,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(
                          context,
                          PlacePickerResult(
                            place: picked,
                            savedLocationId:
                                _selectedSavedLocationId ?? savedId,
                          ),
                        );
                      },
              ),
              filled: true,
              fillColor: const Color(0xFFFAFAE8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final picked = await Navigator.push<MilestoneLocationData>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerPage(
                      placeService: widget.service,
                    ),
                  ),
                );
                if (!context.mounted) return;
                if (picked != null) {
                  setState(() {
                    _selected = picked;
                    _selectedSavedLocationId = null;
                    _ctrl.text = picked.name;
                    _ctrl.selection =
                        TextSelection.collapsed(offset: _ctrl.text.length);
                  });
                  await _persistSelectionIfSaving();
                }
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Seleccionar en el mapa'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _ctrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setState(() {
                            _selected = MilestoneLocationData(name: q);
                            _selectedSavedLocationId = null;
                          });
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    textStyle: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      q.isEmpty ? 'Usar solo texto' : 'Usar solo texto: $q',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final enabling = !_saveToMyPlaces;
                  setState(() => _saveToMyPlaces = enabling);
                  if (enabling) await _persistSelectionIfSaving();
                },
                icon: Icon(_saveToMyPlaces ? Icons.star : Icons.star_border),
                label: const Text('Guardar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  textStyle: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 2),
              itemCount: (showSaved
                      ? (1 + (savedExpandedEffective ? savedFiltered.length : 0))
                      : 0) +
                  (recentsFiltered.isEmpty ? 0 : (1 + recentsFiltered.length)) +
                  (_items.isEmpty ? 1 : _items.length),
              itemBuilder: (context, index) {
                var cursor = 0;
                if (showSaved) {
                  if (index == cursor) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: qLower.isNotEmpty
                          ? null
                          : () => setState(
                                () => _savedExpanded = !_savedExpanded,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MIS LUGARES GUARDADOS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.navy.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            Icon(
                              savedExpandedEffective
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: AppTheme.navy.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  cursor += 1;
                  if (savedExpandedEffective) {
                    final endSaved = cursor + savedFiltered.length;
                    if (index >= cursor && index < endSaved) {
                      final s = savedFiltered[index - cursor];
                      final subtitle = (s.city ?? '').trim();
                      final loc = MilestoneLocationData(
                        name: s.name.trim(),
                        city: s.city,
                        country: s.country,
                        latitude: s.latitude,
                        longitude: s.longitude,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _selected = loc;
                            _selectedSavedLocationId = s.isarId;
                            _ctrl.text = s.name;
                            _ctrl.selection = TextSelection.collapsed(
                              offset: _ctrl.text.length,
                            );
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.star,
                                    size: 18,
                                    color:
                                        AppTheme.navy.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AppTheme.navy.withValues(
                                                alpha: 0.55),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    cursor = endSaved;
                  }
                }
                if (recentsFiltered.isNotEmpty) {
                  if (index == cursor) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(
                        'Sitios recientes',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.navy.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }
                  cursor += 1;
                  final endRecents = cursor + recentsFiltered.length;
                  if (index >= cursor && index < endRecents) {
                    final s = recentsFiltered[index - cursor];
                    final subtitleParts = <String>[
                      if (s.city != null && s.city!.trim().isNotEmpty) s.city!.trim(),
                      if (s.country != null && s.country!.trim().isNotEmpty)
                        s.country!.trim(),
                    ];
                    final subtitle = subtitleParts.join(', ');
                    return InkWell(
                      onTap: () async {
                        setState(() {
                          _selected = s;
                          _selectedSavedLocationId = null;
                          _ctrl.text = s.name;
                          _ctrl.selection =
                              TextSelection.collapsed(offset: _ctrl.text.length);
                        });
                        await _persistSelectionIfSaving();
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.history,
                                size: 18,
                                color: AppTheme.navy.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppTheme.navy.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  cursor = endRecents;
                }

                if (_items.isEmpty) {
                  if (_loading) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _search(_ctrl.text),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navy,
                              side: const BorderSide(color: AppTheme.navy),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _lastQuery.isEmpty ? 'Escribe para ver sugerencias.' : 'Sin resultados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.navy.withValues(alpha: 0.65),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final s = _items[index - cursor];
                final subtitleParts = <String>[
                  if (s.city != null) s.city!,
                  if (s.country != null) s.country!,
                ];
                final subtitle = subtitleParts.join(' · ');
                return InkWell(
                  onTap: () async {
                    setState(() {
                      _selected = s;
                      _selectedSavedLocationId = null;
                      _ctrl.text = s.name;
                      _ctrl.selection =
                          TextSelection.collapsed(offset: _ctrl.text.length);
                    });
                    await _persistSelectionIfSaving();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppTheme.navy.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.navy.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final List<CategoryCollection> categories;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _CategorySelector({
    required this.categories,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  CategoryCollection? _findSelected() {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return categories.firstOrNull;
    return categories.where((c) => c.id == v).firstOrNull ??
        categories.firstOrNull;
  }

  IconData _iconByName(String name) =>
      kCategoryIconPalette[name] ?? Icons.category_outlined;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _CategoryPickerSheet(
        categories: categories,
        selectedId: value.trim().toLowerCase(),
      ),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      onChanged(picked.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _findSelected();
    final name = selected?.name ?? value;
    final color = Color(selected?.colorValue ?? 0xFF9E9E9E);
    final icon = _iconByName(selected?.iconName ?? 'category');

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Categoría',
          filled: true,
          fillColor: const Color(0xFFFAFAE8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.navy.withValues(alpha: enabled ? 0.6 : 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<CategoryCollection> categories;
  final String selectedId;
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
  });

  String _label(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return raw;
    return v[0].toUpperCase() + v.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Selecciona una categoría',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.6,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final c = categories[index];
                final selected = c.id == selectedId;
                final color = Color(c.colorValue);
                final icon =
                    kCategoryIconPalette[c.iconName] ?? Icons.category_outlined;
                return InkWell(
                  onTap: () => Navigator.pop(context, c.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.18)
                          : const Color(0xFFFAFAE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.85)
                            : theme.colorScheme.outline,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _label(c.name),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.navy,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check,
                              size: 18,
                              color: color.withValues(alpha: 0.95)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MilestoneLocationRow extends StatelessWidget {
  final MilestoneLocationData? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _MilestoneLocationRow({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final theme = Theme.of(context);
    final hasValue = v != null && v.name.trim().isNotEmpty;

    final subtitle = hasValue && (v!.city ?? '').trim().isNotEmpty
        ? v.city!.trim()
        : null;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.navy.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navy.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppTheme.navy.withValues(alpha: enabled ? 0.85 : 0.35),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasValue ? v!.name : 'Añadir ubicación',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy.withValues(alpha: hasValue ? 0.95 : 0.55),
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.navy.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasValue)
              IconButton(
                onPressed: enabled ? onClear : null,
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Quitar ubicación',
                color: AppTheme.navy.withValues(alpha: enabled ? 0.7 : 0.3),
              ),
          ],
        ),
      ),
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
  final Set<String> protagonistIds;
  final bool enabled;
  final Future<void> Function()? onAdd;
  final ValueChanged<PersonCollection> onAssignPhoto;
  final ValueChanged<PersonCollection> onToggleProtagonist;
  final ValueChanged<PersonCollection> onRemove;

  const _ParticipantsSection({
    required this.participants,
    required this.protagonistIds,
    required this.enabled,
    required this.onAdd,
    required this.onAssignPhoto,
    required this.onToggleProtagonist,
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
                    final isProtagonist = protagonistIds.contains(p.id);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PersonAvatarBadge(
                          faceImagePath: p.faceImagePath,
                          personName: p.name,
                          onAssignPhoto:
                              enabled ? () => onAssignPhoto(p) : () {},
                        ),
                        Positioned(
                          left: -2,
                          top: -2,
                          child: Material(
                            color: isProtagonist
                                ? Colors.amber
                                : Colors.black26,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: enabled ? () => onToggleProtagonist(p) : null,
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.star,
                                  size: 14,
                                  color: isProtagonist
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
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
