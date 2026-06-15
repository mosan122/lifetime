import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Pantalla de bloqueo genérica para funcionalidades Premium.
///
/// Pasa el [icon] y el [message] específicos de cada feature.
class PremiumGatePlaceholder extends StatelessWidget {
  const PremiumGatePlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppTheme.navy.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.navy,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
