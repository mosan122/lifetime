import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/models/local/person_collection.dart';
import 'person_avatar_badge.dart';

/// Hasta tres avatares circulares superpuestos; si hay más de tres, un cuarto
/// círculo gris muestra `+[N]` con N = personas adicionales.
class FaceStack extends StatelessWidget {
  final List<PersonCollection> people;
  /// IDs de protagonistas (subconjunto de participantes); borde dorado.
  final Set<String> protagonistIds;
  final double diameter;
  final double overlap;

  const FaceStack({
    super.key,
    required this.people,
    this.protagonistIds = const <String>{},
    this.diameter = 26,
    this.overlap = 9,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final step = diameter - overlap;
    final showOverflow = people.length > 3;
    final faces = people.take(3).toList(growable: false);
    final extraCount = people.length - 3;
    final slotCount = faces.length + (showOverflow ? 1 : 0);
    final width = (slotCount - 1) * step + diameter;

    return SizedBox(
      width: width,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * step,
              child: PersonCircleAvatar(
                key: ValueKey<String>(
                  '${faces[i].id}|${protagonistIds.contains(faces[i].id)}|'
                  '${faceImageWidgetCacheKey(faces[i].faceImagePath)}',
                ),
                faceImagePath: faces[i].faceImagePath,
                diameter: diameter,
                semanticLabel: faces[i].name,
                borderWidth:
                    protagonistIds.contains(faces[i].id) ? 2.0 : 1.5,
                borderColor: protagonistIds.contains(faces[i].id)
                    ? Colors.amber
                    : AppTheme.cream,
              ),
            ),
          if (showOverflow)
            Positioned(
              left: 3 * step,
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cream, width: 1.5),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    fontSize: diameter * 0.32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carga personas desde Isar en el orden de [participantIds] y muestra un [FaceStack].
class ParticipantFaceStack extends StatefulWidget {
  final List<String> participantIds;
  final List<String> protagonistIds;
  /// Si coincide con [PersonCollection.linkedUserId], no se muestra la cara
  /// (p. ej. timeline: evitar redundancia con el usuario actual).
  final String? omitFaceForLinkedUserId;
  /// Se pasa desde el timeline cuando cambian datos de persona (p. ej. foto) sin
  /// cambiar [participantIds].
  final int peopleDataRevision;
  final double diameter;
  final double overlap;

  const ParticipantFaceStack({
    super.key,
    required this.participantIds,
    this.protagonistIds = const [],
    this.omitFaceForLinkedUserId,
    this.peopleDataRevision = 0,
    this.diameter = 26,
    this.overlap = 9,
  });

  @override
  State<ParticipantFaceStack> createState() => _ParticipantFaceStackState();
}

class _ParticipantFaceStackState extends State<ParticipantFaceStack> {
  late Future<List<PersonCollection>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadOrdered();
  }

  @override
  void didUpdateWidget(covariant ParticipantFaceStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.participantIds, oldWidget.participantIds) ||
        widget.peopleDataRevision != oldWidget.peopleDataRevision ||
        !listEquals(widget.protagonistIds, oldWidget.protagonistIds) ||
        widget.omitFaceForLinkedUserId != oldWidget.omitFaceForLinkedUserId) {
      setState(() {
        _future = _loadOrdered();
      });
    }
  }

  Future<List<PersonCollection>> _loadOrdered() async {
    final ids = widget.participantIds;
    if (ids.isEmpty) return const [];
    final ds = sl<IsarPersonDataSource>();
    final loaded = await ds.fetchByIds(ids);
    final byId = {for (final p in loaded) p.id: p};
    final proSet = widget.protagonistIds.toSet();
    final omit = widget.omitFaceForLinkedUserId?.trim();
    var ordered = ids
        .map((id) => byId[id])
        .whereType<PersonCollection>()
        .toList();
    if (omit != null && omit.isNotEmpty) {
      ordered = ordered
          .where(
            (p) =>
                (p.linkedUserId ?? '').trim() != omit && p.id != omit,
          )
          .toList();
    }
    ordered.sort((a, b) {
      final ap = proSet.contains(a.id) ? 1 : 0;
      final bp = proSet.contains(b.id) ? 1 : 0;
      return bp.compareTo(ap);
    });
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participantIds.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<PersonCollection>>(
      future: _future,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <PersonCollection>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return FaceStack(
          people: list,
          protagonistIds: widget.protagonistIds.toSet(),
          diameter: widget.diameter,
          overlap: widget.overlap,
        );
      },
    );
  }
}
