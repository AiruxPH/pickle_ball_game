import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_simulation.dart';
import '../match_state.dart';
import '../pickleball_flame_game.dart';
import '../pickleball_rules.dart';

/// Flame visual component for rendering the 3D court environment, including
/// tournament stadium / practice warehouse floor, dynamic cloth net with impact flex,
/// grandstands, practice target rings, and serve trajectory arcs.
class CourtVisualComponent extends Component {
  CourtVisualComponent(this.game);

  final PickleballFlameGame game;

  Offset _proj(double x, double y, [double z = 0]) {
    final p = game.simulation.camera.project(x: x, y: y, elevation: z);
    return Offset(
      (p.x + 1.0) / 2.0 * game.size.x,
      (p.y + 1.0) / 2.0 * game.size.y,
    );
  }

  Path _quad(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double x4,
    double y4,
  ) {
    return Path()
      ..moveTo(_proj(x1, y1).dx, _proj(x1, y1).dy)
      ..lineTo(_proj(x2, y2).dx, _proj(x2, y2).dy)
      ..lineTo(_proj(x3, y3).dx, _proj(x3, y3).dy)
      ..lineTo(_proj(x4, y4).dx, _proj(x4, y4).dy)
      ..close();
  }

  void _drawVerticalWall(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    double height,
    Paint paint,
  ) {
    final p1 = _proj(x1, y1, 0);
    final p2 = _proj(x2, y2, 0);
    final p3 = _proj(x2, y2, height);
    final p4 = _proj(x1, y1, height);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawBench(
    Canvas canvas,
    double x,
    double y,
    double width,
    double length,
    double height,
    Paint paint,
  ) {
    // Top surface
    final p1 = _proj(x - width / 2, y - length / 2, height);
    final p2 = _proj(x + width / 2, y - length / 2, height);
    final p3 = _proj(x + width / 2, y + length / 2, height);
    final p4 = _proj(x - width / 2, y + length / 2, height);

    final topPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(topPath, paint);

    // Front face (if visible)
    final p5 = _proj(x - width / 2, y + length / 2, 0);
    final p6 = _proj(x + width / 2, y + length / 2, 0);
    if (p5.dy > p1.dy) {
      final frontPaint = Paint()..color = paint.color.withValues(alpha: 0.7);
      final frontPath = Path()
        ..moveTo(p4.dx, p4.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p6.dx, p6.dy)
        ..lineTo(p5.dx, p5.dy)
        ..close();
      canvas.drawPath(frontPath, frontPaint);
    }

    // Side face
    if (x > 0) {
      // Right side bench
      final sidePaint = Paint()..color = paint.color.withValues(alpha: 0.5);
      final p7 = _proj(x - width / 2, y - length / 2, 0);
      final sidePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p4.dx, p4.dy)
        ..lineTo(p5.dx, p5.dy)
        ..lineTo(p7.dx, p7.dy)
        ..close();
      canvas.drawPath(sidePath, sidePaint);
    } else {
      // Left side bench
      final sidePaint = Paint()..color = paint.color.withValues(alpha: 0.5);
      final p8 = _proj(x + width / 2, y - length / 2, 0);
      final sidePath = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p6.dx, p6.dy)
        ..lineTo(p8.dx, p8.dy)
        ..close();
      canvas.drawPath(sidePath, sidePaint);
    }
  }

  void _drawGrandstand(Canvas canvas, double courtWidth, double courtLength) {
    final tierPaint = Paint()..color = const Color(0xFF17263A);
    final fasciaPaint = Paint()
      ..color = const Color(0xFF2B425A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final aislePaint = Paint()
      ..color = const Color(0x667DE7F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final spectatorPaint = Paint()..color = const Color(0x99F6B94A);

    for (var row = 0; row < 4; row++) {
      final y = -courtLength * (1.78 + row * 0.21);
      final height = 0.18 + row * 0.14;
      final rowWidth = courtWidth * (2.35 + row * 0.10);
      _drawBench(canvas, 0, y, rowWidth, 0.34, height, tierPaint);

      final left = _proj(-rowWidth / 2, y, height + 0.02);
      final right = _proj(rowWidth / 2, y, height + 0.02);
      canvas.drawLine(left, right, fasciaPaint);

      for (var seat = -8; seat <= 8; seat++) {
        if ((seat + row) % 3 == 0) continue;
        final x = seat * rowWidth / 18;
        final seatPoint = _proj(x, y, height + 0.08);
        canvas.drawCircle(seatPoint, 1.7, spectatorPaint);
      }
    }

    for (final aisleX in [-courtWidth * 0.75, 0.0, courtWidth * 0.75]) {
      canvas.drawLine(
        _proj(aisleX, -courtLength * 1.72, 0.14),
        _proj(aisleX, -courtLength * 2.48, 0.78),
        aislePaint,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final width = GameSimulation.courtWidth;
    final length = GameSimulation.courtLength;
    final kDepth =
        PickleballRules.kitchenDepth; // Regulation Kitchen depth (0.3182)

    // Draw floor
    final floorBack = -length * 6.0;
    final floorFront = length * 6.0;
    final floorW = width * 6.0;

    final isPractice = game.simulation.mapType == MapType.practiceFacility;

    if (isPractice) {
      // Dark high-tech concrete floor
      final concretePaint = Paint()..color = const Color(0xFF1E2630);
      canvas.drawPath(
        _quad(
          -floorW,
          floorBack,
          floorW,
          floorBack,
          floorW,
          floorFront,
          -floorW,
          floorFront,
        ),
        concretePaint,
      );

      // Benches for practice area (Neon Teal)
      final pBenchPaint = Paint()..color = const Color(0xFF00ACC1);
      _drawBench(canvas, -width * 2.5, 0.0, 0.3, 1.0, 0.15, pBenchPaint);
      _drawBench(canvas, -width * 2.5, -0.5, 0.3, 1.0, 0.15, pBenchPaint);
    } else {
      // --- STADIUM MAP ---

      // Solid foundation floor under the entire stadium area (prevents any black voids)
      final stadiumBaseFloorPaint = Paint()..color = const Color(0xFF07121E);
      canvas.drawPath(
        _quad(
          -floorW,
          floorBack,
          floorW,
          floorBack,
          floorW,
          floorFront,
          -floorW,
          floorFront,
        ),
        stadiumBaseFloorPaint,
      );

      final boundsW = width * 3.4;
      final boundsBack = -length * 2.8;
      final boundsFront = length * 2.2;

      // Draw the walls (finite area)
      final wallPaint = Paint()..color = const Color(0xFF0F172A);
      final wallLinesPaint = Paint()
        ..color = const Color(0x333D607A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Back wall
      _drawVerticalWall(
        canvas,
        -boundsW,
        boundsBack,
        boundsW,
        boundsBack,
        1.5,
        wallPaint,
      );
      _drawVerticalWall(
        canvas,
        -boundsW,
        boundsBack,
        boundsW,
        boundsBack,
        1.5,
        wallLinesPaint,
      );
      // Left wall
      _drawVerticalWall(
        canvas,
        -boundsW,
        boundsFront,
        -boundsW,
        boundsBack,
        1.5,
        wallPaint,
      );
      _drawVerticalWall(
        canvas,
        -boundsW,
        boundsFront,
        -boundsW,
        boundsBack,
        1.5,
        wallLinesPaint,
      );
      // Right wall
      _drawVerticalWall(
        canvas,
        boundsW,
        boundsBack,
        boundsW,
        boundsFront,
        1.5,
        wallPaint,
      );
      _drawVerticalWall(
        canvas,
        boundsW,
        boundsBack,
        boundsW,
        boundsFront,
        1.5,
        wallLinesPaint,
      );

      // Outer bounds (Tournament slate outer run-off)
      final outerFloorPaint = Paint()
        ..shader = Gradient.linear(
          _proj(0, boundsBack),
          _proj(0, boundsFront),
          const [Color(0xFF091827), Color(0xFF17394B)],
        );
      canvas.drawPath(
        _quad(
          -boundsW,
          boundsBack,
          boundsW,
          boundsBack,
          boundsW,
          boundsFront,
          -boundsW,
          boundsFront,
        ),
        outerFloorPaint,
      );
    }

    // Court floor (Pacific Blue or High-tech Slate Teal)
    final courtFloorPaint = Paint()
      ..shader = Gradient.linear(_proj(0, -length), _proj(0, length), isPractice
          ? const [Color(0xFF142433), Color(0xFF1C3446)]
          : const [Color(0xFF116B82), Color(0xFF19A6A1)])
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      _quad(-width, -length, width, -length, width, length, -width, length),
      courtFloorPaint,
    );

    // Kitchen floor (Precision Kitchen Teal)
    final kitchenFloorPaint = Paint()
      ..shader = Gradient.linear(_proj(0, -kDepth), _proj(0, kDepth), isPractice
          ? const [Color(0xFF0E1E2B), Color(0xFF122838)]
          : const [Color(0xFF0D536B), Color(0xFF11748A)])
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      _quad(-width, -kDepth, width, -kDepth, width, kDepth, -width, kDepth),
      kitchenFloorPaint,
    );

    // Court outline & lines (Crisp regulation white)
    final lineShadowPaint = Paint()
      ..color = const Color(0x6607111F)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final courtPath = _quad(
      -width,
      -length,
      width,
      -length,
      width,
      length,
      -width,
      length,
    );
    canvas.drawPath(courtPath, lineShadowPaint);
    canvas.drawPath(courtPath, linePaint);

    // Subtle surface bands give the flat court depth without relying on a
    // bitmap texture that would blur at different resolutions.
    final surfaceBandPaint = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1;
    for (var index = -8; index <= 8; index++) {
      final y = index * length / 8;
      canvas.drawLine(_proj(-width, y), _proj(width, y), surfaceBandPaint);
    }

    // Center line
    // Bot side
    canvas.drawLine(_proj(0, -length), _proj(0, -kDepth), linePaint);
    // Player side
    canvas.drawLine(_proj(0, kDepth), _proj(0, length), linePaint);

    // Kitchen lines
    canvas.drawLine(_proj(-width, -kDepth), _proj(width, -kDepth), linePaint);
    canvas.drawLine(_proj(-width, kDepth), _proj(width, kDepth), linePaint);

    // Net
    final netShadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 8;
    canvas.drawLine(
      _proj(-width * 1.1, 0, 0),
      _proj(width * 1.1, 0, 0),
      netShadowPaint,
    );

    final netHeight =
        PickleballRules.netHeight; // Regulation Net height (0.1364)
    final netPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final netTapePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final netMeshPaint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.fill;

    // Cloth mesh flex & ripple calculations
    final sim = game.simulation;
    final intensity = sim.netImpactIntensity;
    final impactX = sim.netImpactX;
    final impactDir = sim.netImpactDirection;

    double netYOffset(double x, double z) {
      if (intensity <= 0.001) return 0.0;
      final dx = x - impactX;
      // Fixed at bottom (z=0), flexes upwards with max deflection near upper-mid net
      final zFactor = math.sin((z / netHeight).clamp(0.0, 1.0) * (math.pi / 2));
      // Gaussian distribution centered at impact point X
      final xFactor = math.exp(-dx * dx / 0.025);
      return impactDir * intensity * 0.035 * zFactor * xFactor;
    }

    // Net mesh (cloth flexes dynamically at impact point)
    const netSegs = 20;
    final netPath = Path()
      ..moveTo(_proj(-width * 1.1, 0, 0).dx, _proj(-width * 1.1, 0, 0).dy)
      ..lineTo(_proj(width * 1.1, 0, 0).dx, _proj(width * 1.1, 0, 0).dy);
    for (var i = netSegs; i >= 0; i--) {
      final x = -width * 1.1 + (width * 2.2 * i / netSegs);
      final y = netYOffset(x, netHeight);
      final pt = _proj(x, y, netHeight);
      netPath.lineTo(pt.dx, pt.dy);
    }
    netPath.close();
    canvas.drawPath(netPath, netMeshPaint);

    final netGridPaint = Paint()
      ..color = const Color(0x66F7FBFF)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    for (var index = 1; index < 10; index++) {
      final x = -width * 1.1 + (width * 2.2 * index / 10);
      final yTop = netYOffset(x, netHeight);
      canvas.drawLine(_proj(x, 0, 0), _proj(x, yTop, netHeight), netGridPaint);
    }
    for (var index = 1; index < 4; index++) {
      final z = netHeight * index / 4;
      final hGridPath = Path()
        ..moveTo(
          _proj(-width * 1.1, netYOffset(-width * 1.1, z), z).dx,
          _proj(-width * 1.1, netYOffset(-width * 1.1, z), z).dy,
        );
      for (var i = 1; i <= netSegs; i++) {
        final x = -width * 1.1 + (width * 2.2 * i / netSegs);
        final y = netYOffset(x, z);
        final pt = _proj(x, y, z);
        hGridPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(hGridPath, netGridPaint);
    }

    // Bottom of net (rigid ground wire)
    canvas.drawLine(
      _proj(-width * 1.1, 0, 0),
      _proj(width * 1.1, 0, 0),
      netTapePaint,
    );
    // Top of net (White tape - flexes with cloth ripple)
    final topTapePath = Path()
      ..moveTo(
        _proj(-width * 1.1, netYOffset(-width * 1.1, netHeight), netHeight).dx,
        _proj(-width * 1.1, netYOffset(-width * 1.1, netHeight), netHeight).dy,
      );
    for (var i = 1; i <= netSegs; i++) {
      final x = -width * 1.1 + (width * 2.2 * i / netSegs);
      final y = netYOffset(x, netHeight);
      final pt = _proj(x, y, netHeight);
      topTapePath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(topTapePath, netTapePaint);

    // Posts (rigid vertical steel poles at ends)
    canvas.drawLine(
      _proj(-width * 1.1, 0, 0),
      _proj(-width * 1.1, 0, netHeight),
      netPaint,
    );
    canvas.drawLine(
      _proj(width * 1.1, 0, 0),
      _proj(width * 1.1, 0, netHeight),
      netPaint,
    );

    // A subdued seating bowl frames the court without competing with the ball
    // or resembling collision/debug geometry.
    if (isPractice) {
      _drawPracticeTargetZones(canvas);
    } else {
      _drawGrandstand(canvas, width, length);
    }

    // Serve Trajectory Guide during player serve
    if (game.simulation.playPhase == MatchPlayPhase.waitingForServe &&
        game.simulation.servingSide == MatchSide.player) {
      _drawServeTrajectoryGuide(canvas);
    }
  }

  Path _buildCourtCirclePath(
    double cx,
    double cy,
    double r, [
    int segments = 24,
  ]) {
    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final theta = i * 2 * math.pi / segments;
      final px = cx + r * math.cos(theta);
      final py = cy + r * math.sin(theta);
      final proj = _proj(px, py, 0);
      if (i == 0) {
        path.moveTo(proj.dx, proj.dy);
      } else {
        path.lineTo(proj.dx, proj.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawPracticeTargetZones(Canvas canvas) {
    final sim = game.simulation;
    final activeTarget = sim.activeTarget;

    for (final target in GameSimulation.practiceTargets) {
      final isActive = target.name == activeTarget.name;
      final outerPath = _buildCourtCirclePath(
        target.x,
        target.y,
        target.radius,
      );

      if (isActive) {
        // Glowing halo for active target
        final haloPaint = Paint()
          ..color = const Color(0x66CCFF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawPath(outerPath, haloPaint);

        // Active outer ring & fill
        final fillPaint = Paint()
          ..color = const Color(0x33CCFF00)
          ..style = PaintingStyle.fill;
        canvas.drawPath(outerPath, fillPaint);

        final strokePaint = Paint()
          ..color = const Color(0xFFCCFF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawPath(outerPath, strokePaint);

        // Inner bullseye
        final innerPath = _buildCourtCirclePath(
          target.x,
          target.y,
          target.radius * 0.45,
        );
        final innerFill = Paint()
          ..color = const Color(0x55CCFF00)
          ..style = PaintingStyle.fill;
        canvas.drawPath(innerPath, innerFill);

        final innerStroke = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawPath(innerPath, innerStroke);

        // Center dot
        final centerProj = _proj(target.x, target.y, 0);
        canvas.drawCircle(
          centerProj,
          3.5,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      } else {
        // Inactive target: subtle holographic zone
        final inactiveFill = Paint()
          ..color = const Color(0x1400E5FF)
          ..style = PaintingStyle.fill;
        canvas.drawPath(outerPath, inactiveFill);

        final inactiveStroke = Paint()
          ..color = const Color(0x5500E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawPath(outerPath, inactiveStroke);

        final centerProj = _proj(target.x, target.y, 0);
        canvas.drawCircle(
          centerProj,
          2.0,
          Paint()..color = const Color(0x8800E5FF),
        );
      }
    }
  }

  void _drawServeTrajectoryGuide(Canvas canvas) {
    final sim = game.simulation;
    final traj = sim.getPlayerServeTrajectory();

    final themeColor = traj.isLegal
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF1744);
    final coreColor = traj.isLegal
        ? const Color(0xFFE0F7FA)
        : const Color(0xFFFFEBEE);

    // 1. Draw 3D glowing parabolic trajectory arc
    final points = traj.points;
    if (points.length >= 2) {
      final glowPaint = Paint()
        ..color = themeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      final corePaint = Paint()
        ..color = coreColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path();
      final p0 = _proj(points[0].x, points[0].y, points[0].z);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < points.length; i++) {
        final pt = _proj(points[i].x, points[i].y, points[i].z);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);

      // Trajectory bead pulses
      final beadPaint = Paint()
        ..color = themeColor
        ..style = PaintingStyle.fill;
      for (int i = 0; i < points.length; i += 4) {
        final pt = _proj(points[i].x, points[i].y, points[i].z);
        canvas.drawCircle(pt, 3.0, beadPaint);
      }
    }

    // 2. Draw landing target crosshair on court floor
    final targetCenter = _proj(traj.targetX, traj.targetY, 0.0);
    final targetScale =
        sim.camera.project(x: traj.targetX, y: traj.targetY).scale;

    // Glowing target zone ring
    final targetFill = Paint()
      ..color = themeColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final targetRing = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * targetScale;

    final r = 18.0 * targetScale;
    canvas.drawOval(
      Rect.fromCenter(center: targetCenter, width: r * 2.2, height: r * 1.1),
      targetFill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: targetCenter, width: r * 2.2, height: r * 1.1),
      targetRing,
    );

    // Crosshair ticks
    final tickPaint = Paint()
      ..color = coreColor
      ..strokeWidth = 2.0 * targetScale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      targetCenter.translate(-r * 1.4, 0),
      targetCenter.translate(-r * 0.4, 0),
      tickPaint,
    );
    canvas.drawLine(
      targetCenter.translate(r * 0.4, 0),
      targetCenter.translate(r * 1.4, 0),
      tickPaint,
    );
    canvas.drawLine(
      targetCenter.translate(0, -r * 0.8),
      targetCenter.translate(0, -r * 0.2),
      tickPaint,
    );
    canvas.drawLine(
      targetCenter.translate(0, r * 0.2),
      targetCenter.translate(0, r * 0.8),
      tickPaint,
    );

    // Bullseye center dot
    canvas.drawCircle(
      targetCenter,
      3.5 * targetScale,
      Paint()
        ..color = coreColor
        ..style = PaintingStyle.fill,
    );
  }
}
