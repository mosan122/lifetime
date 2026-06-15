import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/milestone.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

/// Icono de estado en la nube (solo Premium): nube con check o flecha de subida.
class MilestoneSyncBadge extends StatelessWidget {
  const MilestoneSyncBadge({
    super.key,
    required this.milestone,
    this.onDarkBackground = false,
    this.iconOnly = true,
  });

  final Milestone milestone;
  final bool onDarkBackground;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    if (auth is! AuthAuthenticated || !auth.isPremium) {
      return const SizedBox.shrink();
    }

    final synced = milestone.isFullySyncedToCloud;
    final bg = synced
        ? (onDarkBackground
            ? Colors.green.shade700.withValues(alpha: 0.92)
            : Colors.green.shade50)
        : (onDarkBackground
            ? Colors.orange.shade800.withValues(alpha: 0.92)
            : Colors.orange.shade50);
    final fg = onDarkBackground
        ? Colors.white
        : (synced ? Colors.green.shade900 : Colors.orange.shade900);
    final border = onDarkBackground
        ? Colors.white.withValues(alpha: 0.2)
        : (synced ? Colors.green.shade200 : Colors.orange.shade200);

    final label = synced ? 'Sincronizado' : 'Pendiente';
    final icon = synced ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined;

    final child = iconOnly
        ? Icon(icon, size: onDarkBackground ? 16 : 18, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          );

    return Tooltip(
      message: label,
      child: Container(
        padding: EdgeInsets.all(iconOnly ? 5 : 8),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}

/// Sobre miniaturas del timeline (esquina de la foto).
class MilestoneSyncBadgeOverlay extends StatelessWidget {
  const MilestoneSyncBadgeOverlay({super.key, required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    return MilestoneSyncBadge(
      milestone: milestone,
      onDarkBackground: true,
      iconOnly: true,
    );
  }
}
