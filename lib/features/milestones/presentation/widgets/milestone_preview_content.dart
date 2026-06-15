import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_location_helpers.dart'
    show locationInlineLabel;
import '../../../../core/utils/milestone_display_helpers.dart';
import '../../../../domain/entities/milestone.dart';

/// Cuerpo informativo compartido para previsualizaciones de hito en el mapa.
///
/// Contiene: título, fecha formateada, fila de ubicación (opcional) y el
/// botón "Ver hito completo". El contenedor visual (tarjeta flotante o
/// bottom-sheet) es responsabilidad del widget padre.
///
/// Parámetros de layout:
/// - [infoPadding]: padding alrededor del bloque título + fecha + ubicación.
/// - [buttonPadding]: padding alrededor del botón de acción principal.
///   En sheets donde botón e info comparten el mismo `Padding`, establece
///   `infoPadding.bottom = 0` y añade el espaciado en `buttonPadding.top`.
///
/// Parámetros de presentación:
/// - [titleFallback]: texto cuando `milestone.title` está vacío (ej. 'Hito').
/// - [largeTitleStyle]: `false` → `titleMedium` navy/w800 (tarjeta compacta);
///   `true` → `titleLarge` del tema (sheet con más espacio).
/// - [trailingAction]: widget opcional al lado derecho del título (ej. botón cerrar).
/// - [useFullLocationLabel]: `true` → "Lugar • Ciudad, País" vía
///   [locationInlineLabel]; `false` → solo `milestone.locationName`.
/// - [buttonBorderRadius]: radio de las esquinas del botón (por defecto 10).
class MilestonePreviewContent extends StatelessWidget {
  const MilestonePreviewContent({
    super.key,
    required this.milestone,
    this.onViewDetail,
    this.infoPadding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.buttonPadding = const EdgeInsets.fromLTRB(14, 0, 14, 14),
    this.titleFallback = '',
    this.largeTitleStyle = false,
    this.trailingAction,
    this.useFullLocationLabel = true,
    this.buttonBorderRadius = 10.0,
  });

  final Milestone milestone;
  final VoidCallback? onViewDetail;
  final EdgeInsets infoPadding;
  final EdgeInsets buttonPadding;
  final String titleFallback;
  final bool largeTitleStyle;
  final Widget? trailingAction;
  final bool useFullLocationLabel;
  final double buttonBorderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatEventDate(milestone.eventDate);
    final title =
        milestone.title.trim().isEmpty ? titleFallback : milestone.title;

    final String? location;
    if (milestone.locationName == null) {
      location = null;
    } else if (useFullLocationLabel) {
      final label = locationInlineLabel(milestone);
      location = label.isEmpty ? null : label;
    } else {
      location = milestone.locationName;
    }

    final effectiveTitleStyle = largeTitleStyle
        ? theme.textTheme.titleLarge
        : theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          );

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: effectiveTitleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(formatted, style: theme.textTheme.bodySmall),
        if (location != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_outlined,
                  size: 12, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  location,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: infoPadding,
          child: trailingAction != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoColumn),
                    trailingAction!,
                  ],
                )
              : infoColumn,
        ),
        if (onViewDetail != null)
          Padding(
            padding: buttonPadding,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewDetail,
                style: AppTheme.navyOutlinedButton.copyWith(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(buttonBorderRadius)),
                    ),
                  ),
                ),
                child: const Text('Ver hito completo'),
              ),
            ),
          ),
      ],
    );
  }
}
