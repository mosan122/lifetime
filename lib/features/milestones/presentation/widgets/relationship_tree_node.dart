import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'person_avatar_badge.dart';

/// Nodo circular del grafo: avatar, nombre y parentesco.
class RelationshipTreeNode extends StatelessWidget {
  const RelationshipTreeNode({
    super.key,
    required this.name,
    required this.faceImagePath,
    required this.kinshipLabel,
    this.isDimmed = false,
    this.isCenter = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  final String name;
  final String? faceImagePath;
  final String kinshipLabel;
  final bool isDimmed;
  final bool isCenter;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  static const double avatarSize = 56;
  static const double width = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = isDimmed ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isCenter
                      ? Border.all(color: AppTheme.navy, width: 2.5)
                      : null,
                  boxShadow: isCenter
                      ? [
                          BoxShadow(
                            color: AppTheme.navy.withValues(alpha: 0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: PersonCircleAvatar(
                  faceImagePath: faceImagePath,
                  diameter: avatarSize,
                  semanticLabel: name,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isCenter ? FontWeight.w700 : FontWeight.w600,
                  color: AppTheme.navy,
                ),
              ),
              if (kinshipLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  kinshipLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
