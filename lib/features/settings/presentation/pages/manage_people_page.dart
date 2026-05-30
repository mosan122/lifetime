import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../milestones/data/models/local/group_collection.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/pages/group_constellation_view.dart';
import '../../../milestones/presentation/widgets/face_stack.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../bloc/people_cubit.dart';
import '../widgets/manage_people_relations_tab.dart';
import '../widgets/person_detail_sheet.dart';
import 'add_person_page.dart';

class ManagePeoplePage extends StatefulWidget {
  const ManagePeoplePage({super.key});

  @override
  State<ManagePeoplePage> createState() => _ManagePeoplePageState();
}

class _ManagePeoplePageState extends State<ManagePeoplePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) setState(() {});
    });
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
            Tab(text: 'Relaciones'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              tooltip: 'Añadir persona',
              backgroundColor: AppTheme.navy,
              foregroundColor: AppTheme.cream,
              onPressed: () => _addPerson(context),
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
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
              const ManagePeopleRelationsTab(),
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

    final ordered = [...people]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ordered.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final p = ordered[index];
        final img = p.faceImagePath;
        final hasImg = img != null &&
            img.trim().isNotEmpty &&
            File(img).existsSync();

        final full = _fullName(p);
        final linked =
            p.linkedUserId != null && p.linkedUserId!.trim().isNotEmpty;

        return ListTile(
          onTap: () => showPersonDetailSheet(context, person: p, groups: groups),
          leading: CircleAvatar(
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
            ],
          ),
        );
      },
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: sortedGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final g = sortedGroups[index];
        final members = people
            .where((p) => p.runtimeGroupIds.contains(g.id))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
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
                    diameter: 40,
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
            trailing: Icon(
              Icons.chevron_right,
              color: AppTheme.navy.withValues(alpha: 0.45),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GroupConstellationView(groupId: g.id),
                ),
              );
            },
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
}
