import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/widgets/face_source_bottom_sheet.dart';
import '../../../milestones/presentation/widgets/face_stack.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../../../milestones/presentation/widgets/person_relationships_block.dart';
import '../bloc/people_cubit.dart';
import 'add_person_page.dart';
import 'edit_person_page.dart';

class ManagePeoplePage extends StatefulWidget {
  const ManagePeoplePage({super.key});

  @override
  State<ManagePeoplePage> createState() => _ManagePeoplePageState();
}

class _ManagePeoplePageState extends State<ManagePeoplePage>
    with SingleTickerProviderStateMixin {
  static const String _kFilterAll = '__all__';

  late final TabController _tabController;
  String _filterGroupId = _kFilterAll;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fullName(PersonCollection p) {
    final first = (p.firstName ?? '').trim();
    final last = (p.lastName ?? '').trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    return full;
  }

  String _groupsLabelForPerson(PersonCollection p, List<GroupCollection> groups) {
    final byId = {for (final g in groups) g.id: g.name};
    return p.runtimeGroupIds
        .map((id) => byId[id] ?? '')
        .where((n) => n.trim().isNotEmpty)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar personas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.navy,
          unselectedLabelColor: AppTheme.navy.withValues(alpha: 0.45),
          indicatorColor: AppTheme.navy,
          tabs: const [
            Tab(text: 'Personas'),
            Tab(text: 'Grupos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Añadir persona',
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.cream,
        onPressed: () => _addPerson(context),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: BlocBuilder<PeopleCubit, PeopleState>(
        builder: (context, state) {
          if (state is PeopleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = state as PeopleLoaded;
          final people = loaded.people;
          final groups = loaded.groups;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPersonasTab(context, people, groups),
              _buildGruposTab(context, people, groups),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPersonasTab(
    BuildContext context,
    List<PersonCollection> people,
    List<GroupCollection> groups,
  ) {
    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppTheme.navy.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay contactos en la lista.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Añade personas para hitos y @menciones. Tu nombre, foto y cumple '
                'los editas en Ajustes → Mi perfil.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _addPerson(context),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Añadir persona'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: AppTheme.cream,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final orderedAll = [...people]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    final filterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _kFilterAll,
        child: Text('Todos los grupos'),
      ),
      ...groups.map(
        (g) => DropdownMenuItem(
          value: g.id,
          child: Text(g.name),
        ),
      ),
    ];

    var effectiveFilter = _filterGroupId;
    if (!filterItems.any((e) => e.value == effectiveFilter)) {
      effectiveFilter = _kFilterAll;
    }

    final filtered = effectiveFilter == _kFilterAll
        ? orderedAll
        : orderedAll
            .where((p) => p.runtimeGroupIds.contains(effectiveFilter))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: AppTheme.navy),
              const SizedBox(width: 10),
              Expanded(
                // ignore: deprecated_member_use
                child: DropdownButtonFormField<String>(
                  value: effectiveFilter,
                  items: filterItems,
                  onChanged: (v) =>
                      setState(() => _filterGroupId = v ?? _kFilterAll),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Filtrar por grupo',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (context, index) {
              final p = filtered[index];
              final img = p.faceImagePath;
              final hasImg = img != null &&
                  img.trim().isNotEmpty &&
                  File(img).existsSync();

              final full = _fullName(p);
              final linked = p.linkedUserId != null &&
                  p.linkedUserId!.trim().isNotEmpty;

              return ListTile(
                onTap: () => _openPersonDetailSheet(context, p, groups),
                leading: GestureDetector(
                  onTap: () => _assignPhoto(context, p),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                    child: hasImg
                        ? ClipOval(
                            child: Image(
                              key: ValueKey<String>(
                                faceImageWidgetCacheKey(img),
                              ),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              image: FileImage(File(img)),
                            ),
                          )
                        : const Icon(Icons.person_outline, color: AppTheme.navy),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (linked)
                      const Icon(
                        Icons.bolt,
                        size: 18,
                        color: Colors.blue,
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (full.isNotEmpty)
                      Text(
                        full,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    if (p.driveFaceFileId != null &&
                        p.driveFaceFileId!.trim().isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text('Foto sincronizada en la nube'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGruposTab(
    BuildContext context,
    List<PersonCollection> people,
    List<GroupCollection> groups,
  ) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay grupos definidos.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sortedGroups = [...groups]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final g = sortedGroups[index];
        final members = people
            .where((p) => p.runtimeGroupIds.contains(g.id))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ExpansionTile(
            leading: members.isEmpty
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppTheme.navy,
                    ),
                  )
                : FaceStack(
                    people: members,
                    diameter: 32,
                    overlap: 10,
                  ),
            title: Text(
              g.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            subtitle: Text(
              members.isEmpty
                  ? 'Sin integrantes'
                  : '${members.length} integrante${members.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Añade personas a este grupo desde Editar persona → Grupos.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                for (final p in members)
                  ListTile(
                    dense: true,
                    leading: PersonCircleAvatar(
                      key: ValueKey<String>(
                        '${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}',
                      ),
                      faceImagePath: p.faceImagePath,
                      diameter: 40,
                      semanticLabel: p.name,
                    ),
                    title: Text(p.name),
                    subtitle: _fullName(p).isEmpty
                        ? null
                        : Text(
                            _fullName(p),
                            style: const TextStyle(color: Colors.black54),
                          ),
                    onTap: () => _openPersonDetailSheet(context, p, groups),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePerson(
    BuildContext parentContext,
    PersonCollection p,
  ) async {
    final ok = await showDialog<bool>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar persona'),
        content: Text(
          'Se borrará «${p.name}» de este dispositivo, sus grupos y relaciones.\n\n'
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
    if (ok != true || !parentContext.mounted) return;

    final cubit = parentContext.read<PeopleCubit>();
    final result = await cubit.deletePerson(p.id);
    if (!parentContext.mounted) return;

    result.fold(
      (f) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('«${p.name}» eliminada.')),
        );
      },
    );
  }

  Future<void> _openPersonDetailSheet(
    BuildContext parentContext,
    PersonCollection p,
    List<GroupCollection> groups,
  ) async {
    final theme = Theme.of(parentContext);
    final groupsLabel = _groupsLabelForPerson(p, groups);
    await showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: AppTheme.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        final img = p.faceImagePath;
        final hasImg = img != null &&
            img.trim().isNotEmpty &&
            File(img).existsSync();
        final full = _fullName(p);
        final linked = p.linkedUserId != null &&
            p.linkedUserId!.trim().isNotEmpty;
        final email = (p.linkedUserEmail ?? '').trim();
        final notes = p.notes.trim();
        final birth = p.birthDate;

        Widget detailLine(String label, String value) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.88;
        final fichaEmpty = groupsLabel.isEmpty &&
            birth == null &&
            email.isEmpty &&
            notes.isEmpty &&
            (p.driveFaceFileId == null || p.driveFaceFileId!.trim().isEmpty);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            AppTheme.navy.withValues(alpha: 0.10),
                        child: hasImg
                            ? ClipOval(
                                child: Image(
                                  key: ValueKey<String>(
                                    faceImageWidgetCacheKey(img),
                                  ),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  image: FileImage(File(img)),
                                ),
                              )
                            : const Icon(Icons.person_outline,
                                size: 44, color: AppTheme.navy),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                            ),
                            if (full.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                full,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                            if (linked) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.bolt,
                                      size: 18, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Cuenta LifeTime vinculada',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined,
                            color: AppTheme.navy),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (parentContext.mounted) {
                              _edit(parentContext, p);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: AppTheme.navy,
                  unselectedLabelColor: AppTheme.navy.withValues(alpha: 0.45),
                  indicatorColor: AppTheme.navy,
                  tabs: const [
                    Tab(text: 'Ficha'),
                    Tab(text: 'Relaciones'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          20 + bottomInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (groupsLabel.isNotEmpty)
                              detailLine('Grupos', groupsLabel),
                            if (birth != null)
                              detailLine(
                                'Cumpleaños',
                                '${birth.day.toString().padLeft(2, '0')}/'
                                    '${birth.month.toString().padLeft(2, '0')}/'
                                    '${birth.year}',
                              ),
                            if (email.isNotEmpty) detailLine('Email', email),
                            if (notes.isNotEmpty)
                              detailLine('Notas', notes),
                            if (p.driveFaceFileId != null &&
                                p.driveFaceFileId!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Foto de perfil sincronizada en la nube',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            if (fichaEmpty)
                              Text(
                                'Pulsa el lápiz para completar la ficha o toca la foto en la lista para asignar imagen.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _confirmDeletePerson(parentContext, p);
                              },
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade700),
                              label: Text(
                                'Eliminar persona',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          20 + bottomInset,
                        ),
                        child: PersonRelationshipsBlock(
                          personId: p.id,
                          dense: true,
                          allowDelete: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final cubit = context.read<PeopleCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const AddPersonPage(),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, PersonCollection p) async {
    final cubit = context.read<PeopleCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: EditPersonPage(person: p),
        ),
      ),
    );
  }

  Future<void> _assignPhoto(BuildContext context, PersonCollection p) async {
    final cubit = context.read<PeopleCubit>();
    final faceCropService = sl<FaceCropperService>();

    final selection = await showFaceSourceBottomSheet(context: context);
    if (selection == null || !context.mounted) return;

    final cropResult = await faceCropService.pickAndCrop(
      source: selection.source,
      milestoneImagePath: selection.milestoneImagePath,
    );

    if (!context.mounted) return;
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
          personId: p.id,
          croppedFile: file,
        );
        if (!context.mounted) return;
        saveResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
            ),
          ),
          (_) {},
        );
      },
    );
  }
}
