import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class GroupConstellationConnection {
  const GroupConstellationConnection({
    required this.from,
    required this.to,
  });

  final Offset from;
  final Offset to;
}

class GroupConstellationConnectionPainter extends CustomPainter {
  GroupConstellationConnectionPainter({
    required this.connections,
    this.lineColor = AppTheme.navy,
  });

  final List<GroupConstellationConnection> connections;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final c in connections) {
      canvas.drawLine(c.from, c.to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GroupConstellationConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections;
  }
}
