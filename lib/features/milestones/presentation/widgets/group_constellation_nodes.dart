import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/group_icon_helpers.dart';
import 'relationship_tree_node.dart';

String groupDisplayInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.length >= 2
        ? w.substring(0, 2).toUpperCase()
        : w.toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// Nodo central del grupo (más grande: iniciales o icono + nombre).
class GroupConstellationGroupNode extends StatelessWidget {
  const GroupConstellationGroupNode({
    super.key,
    required this.groupId,
    required this.name,
    this.onTap,
  });

  final String groupId;
  final String name;
  final VoidCallback? onTap;

  static const double diameter = 80;
  static const double width = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = groupIconFor(groupId);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.navy,
                border: Border.all(color: AppTheme.cream, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.22),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: Icon(icon, color: AppTheme.cream, size: 36),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nodo de integrante (avatar + nombre).
///
/// Delega en [RelationshipTreeNode] para evitar duplicar el layout visual de
/// avatar circular + nombre centrado que ambos comparten.
class GroupConstellationMemberNode extends StatelessWidget {
  const GroupConstellationMemberNode({
    super.key,
    required this.name,
    required this.faceImagePath,
    this.onTap,
  });

  final String name;
  final String? faceImagePath;
  final VoidCallback? onTap;

  static const double avatarSize = 56;
  static const double width = 88;

  @override
  Widget build(BuildContext context) {
    return RelationshipTreeNode(
      name: name,
      faceImagePath: faceImagePath,
      kinshipLabel: '',
      isCenter: false,
      isDimmed: false,
      onTap: onTap,
    );
  }
}
