import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Chip compacto que muestra el número de hitos en el AppBar del mapa.
class MilestoneCountBadge extends StatelessWidget {
  const MilestoneCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count hito${count == 1 ? '' : 's'}',
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
