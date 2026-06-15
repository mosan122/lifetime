import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Segmento visual entre el centro del nodo principal y un satélite.
class RelationshipTreeConnection {
  const RelationshipTreeConnection({
    required this.from,
    required this.to,
    required this.isPastPartner,
  });

  final Offset from;
  final Offset to;
  final bool isPastPartner;
}

class RelationshipTreeConnectionPainter extends CustomPainter {
  RelationshipTreeConnectionPainter({
    required this.connections,
    this.lineColor = AppTheme.navy,
  });

  final List<RelationshipTreeConnection> connections;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connections) {
      final paint = Paint()
        ..color = c.isPastPartner
            ? lineColor.withValues(alpha: 0.35)
            : lineColor.withValues(alpha: 0.55)
        ..strokeWidth = c.isPastPartner ? 1.5 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = _curvedPath(c.from, c.to);
      if (c.isPastPartner) {
        _paintDashedPath(canvas, paint, path);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  Path _curvedPath(Offset from, Offset to) {
    final path = Path()..moveTo(from.dx, from.dy);
    final mid = Offset.lerp(from, to, 0.5)!;
    final delta = to - from;
    final normal = Offset(-delta.dy, delta.dx);
    final len = normal.distance;
    final control = len < 1
        ? mid
        : mid + normal / len * (len * 0.12).clamp(12.0, 36.0);
    path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    return path;
  }

  void _paintDashedPath(Canvas canvas, Paint paint, Path path) {
    const dashWidth = 7.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant RelationshipTreeConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.lineColor != lineColor;
  }
}
