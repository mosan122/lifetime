import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/person_display_helpers.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/person_collection.dart';
import '../utils/timeline_filters.dart';

/// Hoja para elegir filtros de persona, lugar y año-mes.
Future<TimelineFilters?> showTimelineFilterSheet({
  required BuildContext context,
  required List<Milestone> allMilestones,
  required TimelineFilters initial,
}) {
  return showModalBottomSheet<TimelineFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cream,
    showDragHandle: true,
    builder: (ctx) => _TimelineFilterSheet(
      allMilestones: allMilestones,
      initial: initial,
    ),
  );
}

class _TimelineFilterSheet extends StatefulWidget {
  const _TimelineFilterSheet({
    required this.allMilestones,
    required this.initial,
  });

  final List<Milestone> allMilestones;
  final TimelineFilters initial;

  @override
  State<_TimelineFilterSheet> createState() => _TimelineFilterSheetState();
}

class _TimelineFilterSheetState extends State<_TimelineFilterSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Set<String> _personIds;
  late Set<String> _locationKeys;
  late Set<(int year, int month)> _yearMonths;

  List<PersonCollection> _people = const [];
  bool _loadingPeople = true;

  final _personSearch = TextEditingController();
  final _locationSearch = TextEditingController();
  final _dateSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _personIds = Set<String>.from(widget.initial.personIds);
    _locationKeys = Set<String>.from(widget.initial.locationKeys);
    _yearMonths = Set<(int, int)>.from(widget.initial.yearMonths);
    _loadPeople();
    for (final c in [_personSearch, _locationSearch, _dateSearch]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _personSearch.dispose();
    _locationSearch.dispose();
    _dateSearch.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    final ids = collectParticipantIds(widget.allMilestones);
    if (ids.isEmpty) {
      if (mounted) setState(() => _loadingPeople = false);
      return;
    }
    final people = await sl<IsarPersonDataSource>().fetchByIds(ids.toList());
    people.sort(comparePeopleRootFirst);
    if (!mounted) return;
    setState(() {
      _people = people;
      _loadingPeople = false;
    });
  }

  TimelineFilters _buildResult() => TimelineFilters(
        personIds: _personIds,
        locationKeys: _locationKeys,
        yearMonths: _yearMonths,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Filtrar timeline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.navy,
                unselectedLabelColor: AppTheme.navy.withValues(alpha: 0.45),
                indicatorColor: AppTheme.navy,
                tabs: [
                  Tab(text: 'Personas (${_personIds.length})'),
                  Tab(text: 'Lugares (${_locationKeys.length})'),
                  Tab(text: 'Fecha (${_yearMonths.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPeopleTab(theme),
                    _buildLocationsTab(theme),
                    _buildDatesTab(theme),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _personIds.clear();
                          _locationKeys.clear();
                          _yearMonths.clear();
                        });
                      },
                      child: const Text('Limpiar'),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, _buildResult()),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleTab(ThemeData theme) {
    if (_loadingPeople) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
    }
    if (_people.isEmpty) {
      return Center(
        child: Text(
          'Ningún hito tiene participantes.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    final q = _personSearch.text;
    final filtered = _people.where((p) => personMatchesQuery(p, q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _personSearch,
            decoration: InputDecoration(
              hintText: 'Buscar persona…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _personSearch.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFAFAE8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Sin coincidencias.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final selected = _personIds.contains(p.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: AppTheme.navy,
                      onChanged: (_) {
                        setState(() {
                          if (selected) {
                            _personIds.remove(p.id);
                          } else {
                            _personIds.add(p.id);
                          }
                        });
                      },
                      title: PersonListTitle(person: p),
                      secondary: p.isMe
                          ? const Icon(Icons.person_pin_outlined,
                              color: AppTheme.navy)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLocationsTab(ThemeData theme) {
    final locations = collectLocationOptions(widget.allMilestones);
    if (locations.isEmpty) {
      return Center(
        child: Text(
          'Ningún hito tiene lugar registrado.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    final q = _locationSearch.text.trim().toLowerCase();
    final entries = locations.entries
        .where((e) => q.isEmpty || e.value.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _locationSearch,
            decoration: InputDecoration(
              hintText: 'Buscar lugar…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _locationSearch.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFAFAE8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'Sin coincidencias.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final selected = _locationKeys.contains(e.key);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: AppTheme.navy,
                      onChanged: (_) {
                        setState(() {
                          if (selected) {
                            _locationKeys.remove(e.key);
                          } else {
                            _locationKeys.add(e.key);
                          }
                        });
                      },
                      title: Text(e.value),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDatesTab(ThemeData theme) {
    final yearMonths = collectYearMonthOptions(widget.allMilestones);
    if (yearMonths.isEmpty) {
      return Center(
        child: Text(
          'No hay fechas que filtrar.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    final q = _dateSearch.text.trim().toLowerCase();
    final filtered = yearMonths
        .where((opt) => q.isEmpty || opt.$2.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _dateSearch,
            decoration: InputDecoration(
              hintText: 'Buscar mes o año…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _dateSearch.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFAFAE8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Sin coincidencias.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final opt = filtered[i];
                    final ym = (opt.$3, opt.$4);
                    final selected = _yearMonths.contains(ym);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: AppTheme.navy,
                      onChanged: (_) {
                        setState(() {
                          if (selected) {
                            _yearMonths.remove(ym);
                          } else {
                            _yearMonths.add(ym);
                          }
                        });
                      },
                      title: Text(opt.$2),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
