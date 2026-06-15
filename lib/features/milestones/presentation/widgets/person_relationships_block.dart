import 'package:flutter/material.dart';

import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/relationships/relationship_reciprocity.dart';
import '../../../../domain/relationships/relationship_type_codes.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/datasources/isar_relationship_datasource.dart';
import '../../data/models/local/person_collection.dart';
import '../../data/models/local/relationship_collection.dart';
import '../../domain/services/relationship_service.dart';

/// Resumen de vínculos para una persona (ficha o pestaña).
class PersonRelationshipsBlock extends StatefulWidget {
  const PersonRelationshipsBlock({
    super.key,
    required this.personId,
    this.dense = false,
    this.allowDelete = true,
  });

  final String personId;
  final bool dense;
  final bool allowDelete;

  @override
  State<PersonRelationshipsBlock> createState() =>
      _PersonRelationshipsBlockState();
}

class _PersonRelationshipsBlockState extends State<PersonRelationshipsBlock> {
  int _refreshToken = 0;

  Future<List<RelationshipCollection>> _load() =>
      sl<IsarRelationshipDataSource>().findInvolvingPerson(widget.personId);

  void _reload() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<IsarRelationshipDataSource>()) {
      return const SizedBox.shrink();
    }
    final relDs = sl<IsarRelationshipDataSource>();
    final personDs = sl<IsarPersonDataSource>();
    final relSvc = sl<RelationshipService>();

    return FutureBuilder<List<RelationshipCollection>>(
      key: ValueKey<int>(_refreshToken),
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Text(
            widget.dense ? 'Sin relaciones registradas.' : 'Aún no hay relaciones.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          );
        }
        return _PersonRelationshipsBody(
          viewerId: widget.personId,
          rows: rows,
          personDs: personDs,
          relSvc: relSvc,
          relDs: relDs,
          dense: widget.dense,
          allowDelete: widget.allowDelete,
          onDeleted: _reload,
        );
      },
    );
  }
}

class _PersonRelationshipsBody extends StatelessWidget {
  const _PersonRelationshipsBody({
    required this.viewerId,
    required this.rows,
    required this.personDs,
    required this.relSvc,
    required this.relDs,
    required this.dense,
    required this.allowDelete,
    required this.onDeleted,
  });

  final String viewerId;
  final List<RelationshipCollection> rows;
  final IsarPersonDataSource personDs;
  final RelationshipService relSvc;
  final IsarRelationshipDataSource relDs;
  final bool dense;
  final bool allowDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final displayRows = _dedupeReciprocalRowsForViewer(rows, relSvc, viewerId);

    return FutureBuilder<Map<String, PersonCollection>>(
      future: _personMap(),
      builder: (context, snap) {
        final byId = snap.data ?? {};

        final active = <RelationshipCollection>[];
        final past = <RelationshipCollection>[];

        for (final r in displayRows) {
          if (RelationshipService.isPast(r)) {
            past.add(r);
          } else {
            active.add(r);
          }
        }

        Widget section(String title, List<RelationshipCollection> list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              ...list.map((r) {
                final line = _relationshipLine(
                  r: r,
                  viewerPersonId: viewerId,
                  byId: byId,
                );
                final dates = _dateLine(r);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppTheme.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (dates != null)
                                  Text(
                                    dates,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),
                          if (allowDelete)
                            IconButton(
                              tooltip: 'Eliminar vínculo',
                              icon: Icon(
                                Icons.delete_outline,
                                size: dense ? 20 : 24,
                                color: AppTheme.navy.withValues(alpha: 0.65),
                              ),
                              onPressed: () => _confirmDelete(
                                context,
                                r,
                                relDs,
                                onDeleted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(height: dense ? 8 : 14),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active.isNotEmpty) section('Relaciones', active),
            section('Relaciones pasadas', past),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RelationshipCollection r,
    IsarRelationshipDataSource relDs,
    VoidCallback onDeleted,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vínculo'),
        content: const Text(
          'Se borrará esta relación y su vínculo recíproco (si existe) en este '
          'dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final soft = sl<PremiumService>().isPremium;
    // Borra también la fila recíproca (p. ej. «madre de» ↔ «hijo de»).
    final involving = await relDs.findInvolvingPerson(r.personId);
    final inverse = relSvc.findInverseRow(r, involving);
    await relDs.deleteById(r.id, softDelete: soft);
    if (inverse != null) {
      await relDs.deleteById(inverse.id, softDelete: soft);
    }
    if (!context.mounted) return;
    onDeleted();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vínculo eliminado.')),
    );
  }

  String? _dateLine(RelationshipCollection r) {
    final a = r.startDate;
    final b = r.endDate;
    if (a == null && b == null) return null;
    final sa = a == null
        ? '?'
        : '${a.day.toString().padLeft(2, '0')}/${a.month.toString().padLeft(2, '0')}/${a.year}';
    final sb = b == null
        ? 'presente'
        : '${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}/${b.year}';
    return '$sa — $sb';
  }

  Future<Map<String, PersonCollection>> _personMap() async {
    final ids = <String>{};
    for (final r in rows) {
      ids.add(r.personId);
      ids.add(r.relatedPersonId);
    }
    final people = await personDs.fetchByIds(ids.toList());
    return {for (final p in people) p.id: p};
  }
}

String _relationshipLine({
  required RelationshipCollection r,
  required String viewerPersonId,
  required Map<String, PersonCollection> byId,
}) {
  return RelationshipTypeCodes.labelFromStoredRow(
    personId: r.personId,
    relatedPersonId: r.relatedPersonId,
    relationshipType: r.relationshipType,
    viewerPersonId: viewerPersonId,
    namePersonId: _nameOf(byId, r.personId),
    nameRelatedPersonId: _nameOf(byId, r.relatedPersonId),
  );
}

String _nameOf(Map<String, PersonCollection> byId, String id) {
  final n = byId[id]?.name.trim();
  return (n != null && n.isNotEmpty) ? n : id;
}

/// Una sola fila por par recíproco: prioriza la que declara la persona que estás viendo
/// (p. ej. «Padre de Elena» en la ficha del padre, no la fila espejo «Hija de …»).
List<RelationshipCollection> _dedupeReciprocalRowsForViewer(
  List<RelationshipCollection> all,
  RelationshipService svc,
  String viewerId,
) {
  final skipIds = <String>{};

  for (final r in all) {
    if (skipIds.contains(r.id)) continue;
    final inv = svc.findInverseRow(r, all);
    if (inv == null || skipIds.contains(inv.id)) continue;

    final mode =
        RelationshipReciprocity.planMirrorForType(r.relationshipType).mode;
    if (mode == RelationshipMirrorMode.none) continue;

    if (mode == RelationshipMirrorMode.symmetricAuto) {
      if (r.id.compareTo(inv.id) <= 0) {
        skipIds.add(inv.id);
      } else {
        skipIds.add(r.id);
      }
      continue;
    }

    final rIsViewerSubject = r.personId == viewerId;
    final invIsViewerSubject = inv.personId == viewerId;
    if (rIsViewerSubject && !invIsViewerSubject) {
      skipIds.add(inv.id);
    } else if (invIsViewerSubject && !rIsViewerSubject) {
      skipIds.add(r.id);
    } else if (r.id.compareTo(inv.id) <= 0) {
      skipIds.add(inv.id);
    } else {
      skipIds.add(r.id);
    }
  }

  return all.where((r) => !skipIds.contains(r.id)).toList();
}
