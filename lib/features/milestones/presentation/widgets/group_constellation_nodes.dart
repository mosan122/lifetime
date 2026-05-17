import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'person_avatar_badge.dart';

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

IconData? builtinGroupIcon(String groupId) {
  switch (groupId) {
    case 'grp_builtin_family':
      return Icons.family_restroom_outlined;
    case 'grp_builtin_best_friends':
      return Icons.favorite_outline;
    case 'grp_builtin_friends':
      return Icons.people_outline;
    case 'grp_builtin_work':
      return Icons.work_outline;
    case 'grp_builtin_school':
      return Icons.school_outlined;
    case 'grp_builtin_neighbors':
      return Icons.home_work_outlined;
    case 'grp_builtin_other':
      return Icons.more_horiz;
    default:
      return null;
  }
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
    final icon = builtinGroupIcon(groupId);
    final initials = groupDisplayInitials(name);

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
                child: icon != null
                    ? Icon(icon, color: AppTheme.cream, size: 36)
                    : Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.cream,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonCircleAvatar(
              faceImagePath: faceImagePath,
              diameter: avatarSize,
              semanticLabel: name,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
