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
  final double diameter;
  final double overlap;

  const FaceStack({
    super.key,
    required this.people,
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
                  '${faces[i].id}|${faceImageWidgetCacheKey(faces[i].faceImagePath)}',
                ),
                faceImagePath: faces[i].faceImagePath,
                diameter: diameter,
                semanticLabel: faces[i].name,
                borderWidth: 1.5,
                borderColor: AppTheme.cream,
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
  final double diameter;
  final double overlap;

  const ParticipantFaceStack({
    super.key,
    required this.participantIds,
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
    if (!listEquals(widget.participantIds, oldWidget.participantIds)) {
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
    return ids.map((id) => byId[id]).whereType<PersonCollection>().toList();
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
          diameter: widget.diameter,
          overlap: widget.overlap,
        );
      },
    );
  }
}
