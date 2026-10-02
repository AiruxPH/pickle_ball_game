import 'package:flutter/material.dart';

import '../game_simulation.dart';
import '../pickleball_rules.dart';

/// Draws a subtle neon boundary highlight over the valid diagonal service box
/// on the receiver's court to clearly show legal landing boundaries.
void drawServeBoxHighlight({
  required Canvas canvas,
  required GameSimulation simulation,
  required Offset Function(double x, double y, double z) project,
}) {
  final isEven = simulation.currentServerScore % 2 == 0;
  // If player serves from right (even), diagonal target is opponent left (-courtWidth to 0).
  // If player serves from left (odd), diagonal target is opponent right (0 to +courtWidth).
  final double xMin = isEven ? -PickleballRules.courtWidth : 0.0;
  final double xMax = isEven ? 0.0 : PickleballRules.courtWidth;

  // Kitchen line is at y = -kitchenDepth (~ -0.3182), baseline is at y = -courtLength (-1.0).
  final double yKitchen = -PickleballRules.kitchenDepth;
  final double yBaseline = -PickleballRules.courtLength;

  final p1 = project(xMin, yKitchen, 0.0);
  final p2 = project(xMax, yKitchen, 0.0);
  final p3 = project(xMax, yBaseline, 0.0);
  final p4 = project(xMin, yBaseline, 0.0);

  final path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..lineTo(p3.dx, p3.dy)
    ..lineTo(p4.dx, p4.dy)
    ..close();

  // Translucent fill
  final fillPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
    ..style = PaintingStyle.fill;
  canvas.drawPath(path, fillPaint);

  // Glowing boundary outline
  final glowPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
  canvas.drawPath(path, glowPaint);

  final borderPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  canvas.drawPath(path, borderPaint);
}
