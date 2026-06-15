import 'dart:math';
import 'package:flutter/material.dart';

/// Logo "Anillos del tiempo" — el símbolo de LifeTime.
///
/// Dibujado con [CustomPainter] para que escale nítidamente a cualquier
/// tamaño sin pasar por raster. Mismo trazo en 16 px que en 320 px.
///
/// Uso:
///   const LifeTimeLogo(size: 80)
///   LifeTimeLogo(size: 24, color: AppTheme.navy)
class LifeTimeLogo extends StatelessWidget {
  final double size;
  final Color color;

  const LifeTimeLogo({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF000080),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LifeTimeLogoPainter(color: color),
      ),
    );
  }
}

class _LifeTimeLogoPainter extends CustomPainter {
  final Color color;
  _LifeTimeLogoPainter({required this.color});

  // Geometría definida en un viewBox conceptual de 100×100.
  // Cuatro anillos concéntricos + punto central. Cada anillo está rotado
  // (i × 25°) y los anillos pares llevan un pequeño hueco al pintar.
  static const _radii = <double>[34.0, 27.0, 20.0, 13.0];
  static const _gapLength = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale);

    const center = Offset(50, 50);

    for (var i = 0; i < _radii.length; i++) {
      final r = _radii[i];
      final strokeWidth = i == 0 ? 3.5 : 2.5;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      canvas.save();
      // Rotar el anillo i por (i × 25°) alrededor del centro.
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 25 * pi / 180);
      canvas.translate(-center.dx, -center.dy);

      if (i.isEven) {
        // Anillo con un pequeño hueco: extraer (circunferencia - hueco)
        // del path de la circunferencia.
        final path = Path()
          ..addOval(Rect.fromCircle(center: center, radius: r));
        for (final metric in path.computeMetrics()) {
          final dashLen = metric.length - _gapLength;
          if (dashLen > 0) {
            canvas.drawPath(metric.extractPath(0, dashLen), paint);
          }
        }
      } else {
        canvas.drawCircle(center, r, paint);
      }

      canvas.restore();
    }

    // Punto central.
    final dot = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LifeTimeLogoPainter old) =>
      old.color != color;
}
