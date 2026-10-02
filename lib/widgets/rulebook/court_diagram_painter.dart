import 'package:flutter/material.dart';

/// CustomPainter rendering an authentic regulation 2D pickleball court diagram.
class CourtDiagramPainter extends CustomPainter {
  final int highlightedZone; // 0: None, 1: Kitchen, 2: Right Service, 3: Left Service, 4: Baselines

  CourtDiagramPainter({this.highlightedZone = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final courtRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Court Surface Fill
    final courtSurfacePaint = Paint()..color = const Color(0xFF0D9488).withValues(alpha: 0.15);
    canvas.drawRRect(RRect.fromRectAndRadius(courtRect, const Radius.circular(8)), courtSurfacePaint);

    // White Perimeter Lines (2 inches in scale)
    final linePaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(RRect.fromRectAndRadius(courtRect, const Radius.circular(8)), linePaint);

    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;

    // Kitchen Depth proportion (7 ft / 22 ft of half court)
    final kitchenHeight = (7.0 / 22.0) * halfHeight;

    // Highlighted Zones
    if (highlightedZone == 1) {
      // Both Non-Volley Zones
      final kitchenPaint = Paint()..color = const Color(0xFFE11D48).withValues(alpha: 0.35);
      canvas.drawRect(Rect.fromLTWH(0, halfHeight - kitchenHeight, size.width, kitchenHeight * 2), kitchenPaint);
    } else if (highlightedZone == 2) {
      // Right Service Box (bottom-right and top-left crosscourts)
      final boxPaint = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.35);
      canvas.drawRect(Rect.fromLTWH(halfWidth, halfHeight + kitchenHeight, halfWidth, halfHeight - kitchenHeight), boxPaint);
      canvas.drawRect(Rect.fromLTWH(0, 0, halfWidth, halfHeight - kitchenHeight), boxPaint);
    } else if (highlightedZone == 3) {
      // Left Service Box (bottom-left and top-right crosscourts)
      final boxPaint = Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.35);
      canvas.drawRect(Rect.fromLTWH(0, halfHeight + kitchenHeight, halfWidth, halfHeight - kitchenHeight), boxPaint);
      canvas.drawRect(Rect.fromLTWH(halfWidth, 0, halfWidth, halfHeight - kitchenHeight), boxPaint);
    } else if (highlightedZone == 4) {
      // Baselines
      final baselinePaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawLine(Offset(0, 0), Offset(size.width, 0), baselinePaint);
      canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), baselinePaint);
    }

    // Non-Volley Zone Lines (Kitchen Lines - 7 ft from net)
    canvas.drawLine(Offset(0, halfHeight - kitchenHeight), Offset(size.width, halfHeight - kitchenHeight), linePaint);
    canvas.drawLine(Offset(0, halfHeight + kitchenHeight), Offset(size.width, halfHeight + kitchenHeight), linePaint);

    // Centerlines: run from NVZ lines to baselines (not through the NVZ!)
    canvas.drawLine(Offset(halfWidth, 0), Offset(halfWidth, halfHeight - kitchenHeight), linePaint);
    canvas.drawLine(Offset(halfWidth, halfHeight + kitchenHeight), Offset(halfWidth, size.height), linePaint);

    // Net line (36" posts, 34" center)
    final netPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(-6, halfHeight), Offset(size.width + 6, halfHeight), netPaint);

    // Net Posts
    final postPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(Offset(-6, halfHeight), 3.5, postPaint);
    canvas.drawCircle(Offset(size.width + 6, halfHeight), 3.5, postPaint);
  }

  @override
  bool shouldRepaint(covariant CourtDiagramPainter oldDelegate) {
    return oldDelegate.highlightedZone != highlightedZone;
  }
}
