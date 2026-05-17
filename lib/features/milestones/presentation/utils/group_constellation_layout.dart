import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Posiciones en órbita circular alrededor de un centro (lienzo 2000×2000).
abstract final class GroupConstellationLayout {
  static const double canvasSize = 2000;
  static const Offset canvasCenter = Offset(canvasSize / 2, canvasSize / 2);
  static const double defaultOrbitRadius = 160;

  /// Reparte [count] puntos en un círculo; el primero arranca arriba (−π/2).
  static List<Offset> orbitPositions({
    required int count,
    Offset center = canvasCenter,
    double radius = defaultOrbitRadius,
  }) {
    if (count <= 0) return const [];
    final step = 2 * math.pi / count;
    const startAngle = -math.pi / 2;
    return List.generate(count, (i) {
      final angle = startAngle + step * i;
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    });
  }
}
