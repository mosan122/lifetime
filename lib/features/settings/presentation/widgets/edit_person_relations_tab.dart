import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/relationships/relationship_reciprocity.dart';
import '../../../../domain/relationships/relationship_type_codes.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/domain/services/relationship_service.dart';
import '../../../milestones/presentation/pages/relationship_tree_view.dart';
import '../../../milestones/presentation/widgets/person_avatar_badge.dart';
import '../../../milestones/presentation/widgets/person_relationships_block.dart';

enum _LinkStep { searchPerson, defineLink }

/// Pestaña «Relaciones» en [EditPersonPage].
class EditPersonRelationsTab extends StatefulWidget {
  const EditPersonRelationsTab({
    super.key,
    required this.subject,
    required this.displayName,
    required this.legalName,
  });

  final PersonCollection subject;
  /// Apodo (cabecera de la pantalla y textos de diálogo).
  final String displayName;
  /// Nombre y apellidos junto a la foto en esta pestaña.
  final String legalName;

  @override
  State<EditPersonRelationsTab> createState() => _EditPersonRelationsTabState();
}

class _EditPersonRelationsTabState extends State<EditPersonRelationsTab> {
  int _listEpoch = 0;

  final _searchCtrl = TextEditingController();
  final _personDs = sl<IsarPersonDataSource>();
  final _svc = sl<RelationshipService>();

  _LinkStep _step = _LinkStep.searchPerson;
  List<PersonCollection> _allPeople = const [];
  PersonCollection? _picked;
  String _type = RelationshipTypeCodes.esPadreDe;
  DateTime? _start;
  DateTime? _end;
  bool _markCurrent = true;
  bool _loadingPeople = true;
  bool _saving = false;

  bool get _showDatesProminent =>
      _type == RelationshipTypeCodes.esParejaDe ||
      _type == RelationshipTypeCodes.esConyugeDe;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    final all = await _personDs.fetchAll();
    if (!mounted) return;
    setState(() {
      _allPeople = all.where((p) => p.id != widget.subject.id).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _loadingPeople = false;
    });
  }

  List<PersonCollection> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _allPeople;
    return _allPeople
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  void _backToSearch() {
    setState(() {
      _step = _LinkStep.searchPerson;
      _picked = null;
      _searchCtrl.clear();
    });
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null && mounted) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _end ?? _start ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null && mounted) {
      setState(() {
        _end = d;
        _markCurrent = false;
      });
    }
  }

  Future<void> _saveBond() async {
    final other = _picked;
    if (other == null) return;
    setState(() => _saving = true);
    try {
      final isCurrent = _markCurrent && _end == null;
      final main = _svc.buildRow(
        personId: widget.subject.id,
        relatedPersonId: other.id,
        relationshipType: _type,
        startDate: _start,
        endDate: _end,
        isCurrent: isCurrent,
      );
      await _svc.saveRow(main);

      // La relación inversa se registra automáticamente, sin preguntar.
      // Para los tipos que admiten varias inversas (p. ej. hijo → padre/madre)
      // se toma la primera opción por defecto.
      final plan = RelationshipService.planFor(_type);
      final chosenMirror =
          plan.mode == RelationshipMirrorMode.chooseMirrorType &&
                  plan.mirrorTypeChoices.isNotEmpty
              ? plan.mirrorTypeChoices.first
              : null;
      await _svc.saveMirrorIfNeeded(
        subjectId: widget.subject.id,
        objectId: other.id,
        forwardType: _type,
        plan: plan,
        chosenMirrorType: chosenMirror,
        startDate: _start,
        endDate: _end,
        isCurrent: isCurrent,
      );

      if (!mounted) return;
      setState(() {
        _listEpoch++;
        _step = _LinkStep.searchPerson;
        _picked = null;
        _searchCtrl.clear();
        _start = null;
        _end = null;
        _markCurrent = true;
        _type = RelationshipTypeCodes.esPadreDe;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vínculo guardado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openGenealogyTree(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RelationshipTreeView(personId: widget.subject.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey<int>(_listEpoch),
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OutlinedButton.icon(
            onPressed: () => _openGenealogyTree(context),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Árbol genealógico'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navy,
              side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PersonCircleAvatar(
              faceImagePath: widget.subject.faceImagePath,
              diameter: 56,
              semanticLabel: widget.legalName.isNotEmpty
                  ? widget.legalName
                  : widget.displayName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.legalName.isNotEmpty)
                    Text(
                      widget.legalName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                    )
                  else
                    Text(
                      'Sin nombre ni apellidos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Vínculos guardados solo en este dispositivo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 16),
        if (_step == _LinkStep.searchPerson) _buildSearchPhase(context),
        if (_step == _LinkStep.defineLink) _buildDefineLinkPhase(context),
        const Divider(height: 32),
        PersonRelationshipsBlock(
          personId: widget.subject.id,
          allowDelete: _step == _LinkStep.searchPerson,
        ),
      ],
    );
  }

  Widget _buildSearchPhase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            labelText: 'Buscar persona',
            hintText: 'Nombre del otro extremo del vínculo',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_loadingPeople)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length.clamp(0, 50),
              itemBuilder: (context, i) {
                final p = _filtered[i];
                final sel = _picked?.id == p.id;
                return Material(
                  color: sel
                      ? AppTheme.navy.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    dense: true,
                    selected: sel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: sel
                          ? const BorderSide(color: AppTheme.navy, width: 2)
                          : BorderSide.none,
                    ),
                    leading: PersonCircleAvatar(
                      faceImagePath: p.faceImagePath,
                      diameter: 40,
                      semanticLabel: p.name,
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.navy,
                      ),
                    ),
                    trailing: sel
                        ? const Icon(Icons.check_circle, color: AppTheme.navy)
                        : null,
                    onTap: () => setState(() => _picked = p),
                  ),
                );
              },
            ),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.navy.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  PersonCircleAvatar(
                    faceImagePath: _picked!.faceImagePath,
                    diameter: 36,
                    semanticLabel: _picked!.name,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seleccionada: ${_picked!.name}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: AppTheme.cream,
                ),
                onPressed: () => setState(() => _step = _LinkStep.defineLink),
                child: const Text('Aceptar'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDefineLinkPhase(BuildContext context) {
    final other = _picked!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _faceColumn(
              context,
              facePath: widget.subject.faceImagePath,
              name: widget.displayName,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
              child: Icon(
                Icons.link,
                size: 32,
                color: AppTheme.navy.withValues(alpha: 0.75),
              ),
            ),
            _faceColumn(
              context,
              facePath: other.faceImagePath,
              name: other.name,
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(_type),
          initialValue: _type,
          decoration: const InputDecoration(
            labelText: 'Tipo de vínculo',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in RelationshipTypeCodes.pickerOrdered)
              DropdownMenuItem(
                value: c,
                child: Text(RelationshipTypeCodes.labelEs(c)),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _type = v);
          },
        ),
        const SizedBox(height: 12),
        if (_showDatesProminent) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inicio'),
            subtitle: Text(
              _start == null
                  ? 'Sin fecha'
                  : '${_start!.day}/${_start!.month}/${_start!.year}',
            ),
            trailing: TextButton(
              onPressed: _pickStart,
              child: const Text('Elegir'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fin (si aplica)'),
            subtitle: Text(
              _end == null
                  ? 'Sin fecha'
                  : '${_end!.day}/${_end!.month}/${_end!.year}',
            ),
            trailing: TextButton(
              onPressed: _pickEnd,
              child: const Text('Elegir'),
            ),
          ),
        ] else
          ExpansionTile(
            title: const Text('Fechas (opcional)'),
            children: [
              ListTile(
                title: const Text('Inicio'),
                subtitle: Text(
                  _start == null
                      ? '—'
                      : '${_start!.day}/${_start!.month}/${_start!.year}',
                ),
                trailing: TextButton(
                  onPressed: _pickStart,
                  child: const Text('Elegir'),
                ),
              ),
              ListTile(
                title: const Text('Fin'),
                subtitle: Text(
                  _end == null
                      ? '—'
                      : '${_end!.day}/${_end!.month}/${_end!.year}',
                ),
                trailing: TextButton(
                  onPressed: _pickEnd,
                  child: const Text('Elegir'),
                ),
              ),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Relación vigente'),
          value: _markCurrent && _end == null,
          onChanged: _end != null
              ? null
              : (v) => setState(() => _markCurrent = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _saving ? null : _backToSearch,
              child: const Text('Volver'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: AppTheme.cream,
              ),
              onPressed: _saving ? null : _saveBond,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar vínculo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _faceColumn(
    BuildContext context, {
    required String? facePath,
    required String name,
  }) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          PersonCircleAvatar(
            faceImagePath: facePath,
            diameter: 64,
            semanticLabel: name,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
          ),
        ],
      ),
    );
  }
}
