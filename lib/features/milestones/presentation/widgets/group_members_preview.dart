import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/local/person_collection.dart';
import 'person_avatar_badge.dart';

/// Ordena integrantes por actividad en hitos (más hitos primero) y luego por nombre.
List<PersonCollection> sortPeopleByMilestoneActivity(
  List<PersonCollection> people,
  Map<String, int> milestoneCountsByPersonId,
) {
  final sorted = [...people];
  sorted.sort((a, b) {
    final ca = milestoneCountsByPersonId[a.id] ?? 0;
    final cb = milestoneCountsByPersonId[b.id] ?? 0;
    if (ca != cb) return cb.compareTo(ca);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// Muestra hasta [maxVisible] avatares (los más activos) y un desplegable «+X más».
class GroupMembersPreview extends StatefulWidget {
  const GroupMembersPreview({
    super.key,
    required this.members,
    this.maxVisible = 20,
    this.avatarDiameter = 34,
  });

  final List<PersonCollection> members;
  final int maxVisible;
  final double avatarDiameter;

  @override
  State<GroupMembersPreview> createState() => _GroupMembersPreviewState();
}

class _GroupMembersPreviewState extends State<GroupMembersPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) return const SizedBox.shrink();

    final visible = widget.members.take(widget.maxVisible).toList();
    final hidden = widget.members.length > widget.maxVisible
        ? widget.members.sublist(widget.maxVisible)
        : const <PersonCollection>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in visible)
              PersonCircleAvatar(
                key: ValueKey<String>(
                  '${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}',
                ),
                faceImagePath: p.faceImagePath,
                diameter: widget.avatarDiameter,
                semanticLabel: p.name,
                borderWidth: 1.5,
                borderColor: AppTheme.cream,
              ),
          ],
        ),
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppTheme.navy,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${hidden.length} más',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in hidden)
                  PersonCircleAvatar(
                    key: ValueKey<String>(
                      'extra|${p.id}|${faceImageWidgetCacheKey(p.faceImagePath)}',
                    ),
                    faceImagePath: p.faceImagePath,
                    diameter: widget.avatarDiameter,
                    semanticLabel: p.name,
                    borderWidth: 1.5,
                    borderColor: AppTheme.cream,
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
