import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect, Gradient, RRect, Radius, MaskFilter, BlurStyle;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'game_debug_config.dart';
import 'game_simulation.dart';

class PickleballFlameGame extends FlameGame {
  PickleballFlameGame({
    GameSimulation? simulation,
    this.onRallyEnd,
  }) : simulation = simulation ?? GameSimulation();

  static const double fixedStep = 0.025;

  final GameSimulation simulation;
  void Function(RallyEnd event)? onRallyEnd;
  double inputX = 0;
  double inputY = 0;
  double _timeAccumulator = 0;
  bool isPlaying = false;
  bool isSwinging = false;
  bool isBotSwinging = false;
  bool isDashing = false;  // Player dash VFX state
  double _dashVfxTimer = 0.0;

  void spawnDashEffect({required double x, required double y, required bool isPlayer}) {
    final point = simulation.camera.project(x: x, y: y);
    final center = Offset(
      (point.x + 1.0) / 2.0 * size.x,
      (point.y + 1.0) / 2.0 * size.y,
    );
    add(DashEffectComponent(center: center, scale: point.scale, isPlayer: isPlayer));
    if (isPlayer) {
      isDashing = true;
      _dashVfxTimer = 0.25;
    }
  }

  @override
  Future<void> onLoad() async {
    await add(CourtVisualComponent(this));
    await add(BallVisualComponent(this));
    await add(BotVisualComponent(this));
    await add(PlayerVisualComponent(this));
  }

  void start() {
    isPlaying = true;
  }

  void spawnHitEffect({required bool isSmash}) {
    final point = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final center = Offset(
      (point.x + 1.0) / 2.0 * size.x,
      (point.y + 1.0) / 2.0 * size.y,
    );
    add(HitEffectComponent(center: center, isSmash: isSmash, scale: point.scale));
    
    // Add camera shake for impact
    if (isSmash) {
      simulation.camera.addShake(1.0);
    } else {
      simulation.camera.addShake(0.3);
    }
  }

  void stop() {
    isPlaying = false;
    inputX = 0;
    inputY = 0;
  }

  @override
  void update(double dt) {
    simulation.camera.updateSize(size.x, size.y);
    super.update(dt);
    if (!isPlaying) return;

    _timeAccumulator += (dt.clamp(0, 0.1) * GameDebugConfig.gameSpeed);
    final keyboard = HardwareKeyboard.instance;
    var currentInputX = inputX;
    var currentInputY = inputY;
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyA) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      currentInputX -= 1;
    }
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyD) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight)) {
      currentInputX += 1;
    }
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyW) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowUp)) {
      currentInputY -= 1;
    }
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyS) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowDown)) {
      currentInputY += 1;
    }

    final prevVy = simulation.ball.velocityY;

    while (_timeAccumulator >= fixedStep) {
      final rallyEnd = simulation.update(
        joystickX: currentInputX.clamp(-1, 1),
        joystickY: currentInputY.clamp(-1, 1),
      );
      _timeAccumulator -= fixedStep;
      
      if (prevVy < 0 && simulation.ball.velocityY > 0) {
        isBotSwinging = true;
        botSwingTimer = 0.15;
        simulation.camera.addShake(0.4); // Bot hit impact
      }
      
      if (rallyEnd != null) {
        onRallyEnd?.call(rallyEnd);
      }
    }
    
    if (botSwingTimer > 0) {
      botSwingTimer -= dt;
      if (botSwingTimer <= 0) isBotSwinging = false;
    }
    if (_dashVfxTimer > 0) {
      _dashVfxTimer -= dt;
      if (_dashVfxTimer <= 0) isDashing = false;
    }
  }

  double botSwingTimer = 0;
}

class BallVisualComponent extends Component {
  BallVisualComponent(this.game);

  final PickleballFlameGame game;
  final List<Offset> _trail = [];
  final List<double> _trailScales = [];

  @override
  void update(double dt) {
    super.update(dt);
    
    final simulation = game.simulation;
    final ballPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final ballCenter = Offset(
      (ballPoint.x + 1.0) / 2.0 * game.size.x,
      (ballPoint.y + 1.0) / 2.0 * game.size.y,
    );
    
    // Only add to trail if ball is moving fast enough
    if (simulation.ball.velocityX.abs() > 0.005 || simulation.ball.velocityY.abs() > 0.005) {
      _trail.add(ballCenter);
      _trailScales.add(ballPoint.scale * simulation.ballScale());
      if (_trail.length > 8) {
        _trail.removeAt(0);
        _trailScales.removeAt(0);
      }
    } else {
      if (_trail.isNotEmpty) {
        _trail.removeAt(0);
        _trailScales.removeAt(0);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final shadowPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
    );
    final ballPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final shadowCenter = Offset(
      (shadowPoint.x + 1.0) / 2.0 * game.size.x,
      (shadowPoint.y + 1.0) / 2.0 * game.size.y,
    );
    final ballCenter = Offset(
      (ballPoint.x + 1.0) / 2.0 * game.size.x,
      (ballPoint.y + 1.0) / 2.0 * game.size.y,
    );
    
    final depthScale = shadowPoint.scale; 
    final shadowScale = depthScale * simulation.ballShadowScale();
    final ballScale = depthScale * simulation.ballScale();

    // Draw shadow
    final shadowPaint = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: 18 * shadowScale,
        height: 8 * shadowScale,
      ),
      shadowPaint,
    );

    // Draw trail
    for (int i = 0; i < _trail.length; i++) {
      final progress = (i + 1) / _trail.length;
      final opacity = progress * 0.4;
      final sizeMult = progress; 
      final trailPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 0, opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(_trail[i], 22.5 * _trailScales[i] * sizeMult, trailPaint);
    }

    final ballPaint = Paint()
      ..shader = Gradient.radial(
        ballCenter.translate(-3 * ballScale, -3 * ballScale),
        11 * ballScale,
        [const Color(0xFFF4FF81), const Color(0xFFD4E157), const Color(0xFF9E9D24)],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballCenter, 11 * ballScale, ballPaint);
  }
}

class BotVisualComponent extends Component {
  BotVisualComponent(this.game);

  final PickleballFlameGame game;

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final isPractice = simulation.gameMode == GameMode.freeRoamPractice;
    
    final point = simulation.camera.project(
      x: isPractice ? 0.0 : simulation.botX,
      y: isPractice ? -GameSimulation.courtLength : simulation.botY,
    );
    final scale = point.scale;
    final center = Offset(
      (point.x + 1.0) / 2.0 * game.size.x,
      (point.y + 1.0) / 2.0 * game.size.y,
    );
    final shadowPaint = Paint()..color = const Color(0x40000000)..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 10 * scale), width: 40 * scale, height: 16 * scale),
      shadowPaint,
    );

    if (isPractice) {
      // Draw ball machine
      final machinePaint = Paint()..color = const Color(0xFF455A64)..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(0, -10 * scale), width: 30 * scale, height: 40 * scale),
          const Radius.circular(8),
        ),
        machinePaint,
      );
      
      // Draw nozzle
      final nozzlePaint = Paint()..color = const Color(0xFF212121)..style = PaintingStyle.fill;
      canvas.drawCircle(center.translate(0, -15 * scale), 12 * scale, nozzlePaint);
      
      final indicatorPaint = Paint()..color = (simulation.ballMachineTimer < 30) ? const Color(0xFFFF5252) : const Color(0xFF69F0AE)..style = PaintingStyle.fill;
      canvas.drawCircle(center.translate(0, -15 * scale), 6 * scale, indicatorPaint);
    } else {
      final paint = Paint()
        ..shader = Gradient.radial(
          center.translate(-5 * scale, -5 * scale),
          22.5 * scale,
          [const Color(0xFFFF8A80), const Color(0xFFFF5252), const Color(0xFFC62828)],
          [0.0, 0.5, 1.0],
        );
      canvas.drawCircle(center, 22.5 * scale, paint);
      final iconPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale;
      canvas.drawCircle(center, 10 * scale, iconPaint);

      final racketPaint = Paint()
        ..color = const Color(0xFFE91E63) // Pink paddle for the bot
        ..style = PaintingStyle.fill;
        
      final handOffset = Offset(-24 * scale, 5 * scale);
      
      canvas.save();
      canvas.translate(center.dx + handOffset.dx, center.dy + handOffset.dy);
      
      if (game.isBotSwinging) {
        canvas.rotate(0.78);
      }
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -12 * scale), width: 14 * scale, height: 32 * scale),
          const Radius.circular(6),
        ),
        racketPaint,
      );
      canvas.restore();
    }

    if (!isPractice && GameDebugConfig.showHitboxes) _drawHitbox(canvas, simulation);
  }

  void _drawHitbox(Canvas canvas, GameSimulation sim) {
    Offset proj(double x, double y, double z) {
      final p = sim.camera.project(x: x, y: y, elevation: z);
      return Offset((p.x + 1.0) / 2.0 * game.size.x, (p.y + 1.0) / 2.0 * game.size.y);
    }

    final pX = sim.botX;
    final pY = sim.botY;
    final rX = sim.botHitRadiusX;
    final rY = sim.botHitRadiusY;
    final zMin = sim.botHitZMin;
    final zMax = sim.botHitZMax;

    final pathMin = Path()
      ..moveTo(proj(pX - rX, pY - rY, zMin).dx, proj(pX - rX, pY - rY, zMin).dy)
      ..lineTo(proj(pX + rX, pY - rY, zMin).dx, proj(pX + rX, pY - rY, zMin).dy)
      ..lineTo(proj(pX + rX, pY + rY, zMin).dx, proj(pX + rX, pY + rY, zMin).dy)
      ..lineTo(proj(pX - rX, pY + rY, zMin).dx, proj(pX - rX, pY + rY, zMin).dy)
      ..close();
    
    final pathMax = Path()
      ..moveTo(proj(pX - rX, pY - rY, zMax).dx, proj(pX - rX, pY - rY, zMax).dy)
      ..lineTo(proj(pX + rX, pY - rY, zMax).dx, proj(pX + rX, pY - rY, zMax).dy)
      ..lineTo(proj(pX + rX, pY + rY, zMax).dx, proj(pX + rX, pY + rY, zMax).dy)
      ..lineTo(proj(pX - rX, pY + rY, zMax).dx, proj(pX - rX, pY + rY, zMax).dy)
      ..close();

    final paint = Paint()..color = const Color(0xAA00FF00)..style = PaintingStyle.stroke..strokeWidth = 2;
    final fillPaint = Paint()..color = const Color(0x2200FF00)..style = PaintingStyle.fill;
    
    canvas.drawPath(pathMin, paint);
    canvas.drawPath(pathMax, paint);
    canvas.drawPath(pathMax, fillPaint);

    canvas.drawLine(proj(pX - rX, pY - rY, zMin), proj(pX - rX, pY - rY, zMax), paint);
    canvas.drawLine(proj(pX + rX, pY - rY, zMin), proj(pX + rX, pY - rY, zMax), paint);
    canvas.drawLine(proj(pX + rX, pY + rY, zMin), proj(pX + rX, pY + rY, zMax), paint);
    canvas.drawLine(proj(pX - rX, pY + rY, zMin), proj(pX - rX, pY + rY, zMax), paint);
  }
}

class PlayerVisualComponent extends Component {
  PlayerVisualComponent(this.game);

  final PickleballFlameGame game;

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final point = simulation.camera.project(
      x: simulation.playerX,
      y: simulation.playerY,
    );
    final scale = point.scale;
    final center = Offset(
      (point.x + 1.0) / 2.0 * game.size.x,
      (point.y + 1.0) / 2.0 * game.size.y,
    );
        // Hit flash: brighter body + amber glow ring while swinging
    final bodyColor =
        game.isSwinging ? const Color(0xFF82B1FF) : const Color(0xFF448AFF);
    final highlightColor =
        game.isSwinging ? const Color(0xFFB3E5FC) : const Color(0xFF82B1FF);
    final shadowColor =
        game.isSwinging ? const Color(0xFF1976D2) : const Color(0xFF0D47A1);

    final shadowPaintFloor = Paint()..color = const Color(0x40000000)..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 10 * scale), width: 45 * scale, height: 18 * scale),
      shadowPaintFloor,
    );

    final playerPaint = Paint()
      ..shader = Gradient.radial(
        center.translate(-6 * scale, -6 * scale),
        25 * scale,
        [highlightColor, bodyColor, shadowColor],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, 25 * scale, playerPaint);
    final outlinePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawCircle(center, 25 * scale, outlinePaint);
    if (game.isSwinging) {
      final glowPaint = Paint()
        ..color = const Color(0x99FFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale;
      canvas.drawCircle(center, 32 * scale, glowPaint);
    }
    if (game.isDashing) {
      final dashGlowPaint = Paint()
        ..color = const Color(0xBB00B0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale;
      canvas.drawCircle(center, 34 * scale, dashGlowPaint);
    }

    final racketPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;
      
    // The player's hand offset relative to the character center
    final handOffset = Offset(24 * scale, 5 * scale);
    
    canvas.save();
    canvas.translate(center.dx + handOffset.dx, center.dy + handOffset.dy);
    
    // Rotate the paddle by -45 degrees (-0.78 rad) if swinging
    if (game.isSwinging) {
      canvas.rotate(-0.78);
    }
    
    // Draw paddle centered around its handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -12 * scale), width: 14 * scale, height: 32 * scale),
        const Radius.circular(6),
      ),
      racketPaint,
    );
    canvas.restore();

    if (GameDebugConfig.showHitboxes) _drawHitbox(canvas, simulation);
  }

  void _drawHitbox(Canvas canvas, GameSimulation sim) {
    Offset proj(double x, double y, double z) {
      final p = sim.camera.project(x: x, y: y, elevation: z);
      return Offset((p.x + 1.0) / 2.0 * game.size.x, (p.y + 1.0) / 2.0 * game.size.y);
    }

    final pX = sim.playerX;
    final pY = sim.playerY;
    final rX = sim.playerHitRadiusX;
    final rY = sim.playerHitRadiusY;
    final zMin = sim.playerHitZMin;
    final zMax = sim.playerHitZMax;

    final pathMin = Path()
      ..moveTo(proj(pX - rX, pY - rY, zMin).dx, proj(pX - rX, pY - rY, zMin).dy)
      ..lineTo(proj(pX + rX, pY - rY, zMin).dx, proj(pX + rX, pY - rY, zMin).dy)
      ..lineTo(proj(pX + rX, pY + rY, zMin).dx, proj(pX + rX, pY + rY, zMin).dy)
      ..lineTo(proj(pX - rX, pY + rY, zMin).dx, proj(pX - rX, pY + rY, zMin).dy)
      ..close();
    
    final pathMax = Path()
      ..moveTo(proj(pX - rX, pY - rY, zMax).dx, proj(pX - rX, pY - rY, zMax).dy)
      ..lineTo(proj(pX + rX, pY - rY, zMax).dx, proj(pX + rX, pY - rY, zMax).dy)
      ..lineTo(proj(pX + rX, pY + rY, zMax).dx, proj(pX + rX, pY + rY, zMax).dy)
      ..lineTo(proj(pX - rX, pY + rY, zMax).dx, proj(pX - rX, pY + rY, zMax).dy)
      ..close();

    final paint = Paint()..color = const Color(0xAAFF0000)..style = PaintingStyle.stroke..strokeWidth = 2;
    final fillPaint = Paint()..color = const Color(0x22FF0000)..style = PaintingStyle.fill;
    
    canvas.drawPath(pathMin, paint);
    canvas.drawPath(pathMax, paint);
    canvas.drawPath(pathMax, fillPaint);

    canvas.drawLine(proj(pX - rX, pY - rY, zMin), proj(pX - rX, pY - rY, zMax), paint);
    canvas.drawLine(proj(pX + rX, pY - rY, zMin), proj(pX + rX, pY - rY, zMax), paint);
    canvas.drawLine(proj(pX + rX, pY + rY, zMin), proj(pX + rX, pY + rY, zMax), paint);
    canvas.drawLine(proj(pX - rX, pY + rY, zMin), proj(pX - rX, pY + rY, zMax), paint);
  }
}

class CourtVisualComponent extends Component {
  CourtVisualComponent(this.game);

  final PickleballFlameGame game;

  Offset _proj(double x, double y, [double z = 0]) {
    final p = game.simulation.camera.project(x: x, y: y, elevation: z);
    return Offset((p.x + 1.0) / 2.0 * game.size.x, (p.y + 1.0) / 2.0 * game.size.y);
  }

  Path _quad(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4) {
    return Path()
      ..moveTo(_proj(x1, y1).dx, _proj(x1, y1).dy)
      ..lineTo(_proj(x2, y2).dx, _proj(x2, y2).dy)
      ..lineTo(_proj(x3, y3).dx, _proj(x3, y3).dy)
      ..lineTo(_proj(x4, y4).dx, _proj(x4, y4).dy)
      ..close();
  }

  void _drawBench(Canvas canvas, double x, double y, double width, double length, double height, Paint paint) {
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
    if (x > 0) { // Right side bench
      final sidePaint = Paint()..color = paint.color.withValues(alpha: 0.5);
      final p7 = _proj(x - width / 2, y - length / 2, 0);
      final sidePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p4.dx, p4.dy)
        ..lineTo(p5.dx, p5.dy)
        ..lineTo(p7.dx, p7.dy)
        ..close();
      canvas.drawPath(sidePath, sidePaint);
    } else { // Left side bench
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

  @override
  void render(Canvas canvas) {
    final width = GameSimulation.courtWidth;
    final length = GameSimulation.courtLength;
    final kDepth = 0.3; // Kitchen depth

    // Draw floor
    final floorBack = -length * 6.0;
    final floorFront = 1.75; 
    final floorW = width * 6.0;
    
    if (game.simulation.mapType == MapType.practiceFacility) {
      // Dark high-tech concrete floor
      final concretePaint = Paint()..color = const Color(0xFF1E2630);
      canvas.drawPath(
        _quad(-floorW, floorBack, floorW, floorBack, floorW, floorFront, -floorW, floorFront),
        concretePaint,
      );
      
      // Draw practice target circles on the wall/floor (Neon Teal - #18FFFF)
      final targetPaint = Paint()..color = const Color(0x1A18FFFF)..style = PaintingStyle.fill;
      final targetBorder = Paint()..color = const Color(0x8018FFFF)..style = PaintingStyle.stroke..strokeWidth = 2;
      
      canvas.drawCircle(_proj(-0.3, -length + 0.2), 35, targetPaint);
      canvas.drawCircle(_proj(-0.3, -length + 0.2), 35, targetBorder);
      
      canvas.drawCircle(_proj(0.3, -length + 0.2), 35, targetPaint);
      canvas.drawCircle(_proj(0.3, -length + 0.2), 35, targetBorder);
      
      // Benches for practice area (Neon Teal)
      final pBenchPaint = Paint()..color = const Color(0xFF00ACC1);
      _drawBench(canvas, -width * 2.5, 0.0, 0.3, 1.0, 0.15, pBenchPaint);
      _drawBench(canvas, -width * 2.5, -0.5, 0.3, 1.0, 0.15, pBenchPaint);
      
      return; // No net or kitchen for practice facility
    }

    // --- STADIUM MAP ---
    
    // Outer bounds (Tournament slate outer run-off)
    final outerFloorPaint = Paint()..color = const Color(0xFF162544);
    canvas.drawPath(
      _quad(-floorW, floorBack, floorW, floorBack, floorW, floorFront, -floorW, floorFront),
      outerFloorPaint,
    );

    // Court floor (Pacific Blue)
    final courtFloorPaint = Paint()..color = const Color(0xFF0284C7)..style = PaintingStyle.fill;
    canvas.drawPath(
      _quad(-width, -length, width, -length, width, length, -width, length),
      courtFloorPaint,
    );

    // Kitchen floor (Precision Kitchen Teal)
    final kitchenFloorPaint = Paint()..color = const Color(0xFF0369A1)..style = PaintingStyle.fill;
    canvas.drawPath(
      _quad(-width, -kDepth, width, -kDepth, width, kDepth, -width, kDepth),
      kitchenFloorPaint,
    );

    // Court outline & lines (Crisp regulation white)
    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final courtPath = _quad(-width, -length, width, -length, width, length, -width, length);
    canvas.drawPath(courtPath, linePaint);

    // Center line
    // Bot side
    canvas.drawLine(_proj(0, -length), _proj(0, -kDepth), linePaint);
    // Player side
    canvas.drawLine(_proj(0, kDepth), _proj(0, length), linePaint);

    // Kitchen lines
    canvas.drawLine(_proj(-width, -kDepth), _proj(width, -kDepth), linePaint);
    canvas.drawLine(_proj(-width, kDepth), _proj(width, kDepth), linePaint);

    // Net
    final netShadowPaint = Paint()..color = const Color(0x66000000)..strokeWidth = 8;
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(width * 1.1, 0, 0), netShadowPaint);

    final netHeight = 0.18;
    final netPaint = Paint()..color = const Color(0xFFF8FAFC)..strokeWidth = 3..style = PaintingStyle.stroke;
    final netTapePaint = Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 4..style = PaintingStyle.stroke;
    final netMeshPaint = Paint()..color = const Color(0x44FFFFFF)..style = PaintingStyle.fill;
        
    // Net mesh
    final netPath = Path()
      ..moveTo(_proj(-width * 1.1, 0, 0).dx, _proj(-width * 1.1, 0, 0).dy)
      ..lineTo(_proj(width * 1.1, 0, 0).dx, _proj(width * 1.1, 0, 0).dy)
      ..lineTo(_proj(width * 1.1, 0, netHeight).dx, _proj(width * 1.1, 0, netHeight).dy)
      ..lineTo(_proj(-width * 1.1, 0, netHeight).dx, _proj(-width * 1.1, 0, netHeight).dy)
      ..close();
    canvas.drawPath(netPath, netMeshPaint);

    // Bottom of net
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(width * 1.1, 0, 0), netTapePaint);
    // Top of net (White tape)
    canvas.drawLine(_proj(-width * 1.1, 0, netHeight), _proj(width * 1.1, 0, netHeight), netTapePaint);
    // Posts
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(-width * 1.1, 0, netHeight), netPaint);
    canvas.drawLine(_proj(width * 1.1, 0, 0), _proj(width * 1.1, 0, netHeight), netPaint);

    // Benches for stadium (Championship Gold)
    final sBenchPaint = Paint()..color = const Color(0xFFF59E0B);
    // Left side benches
    _drawBench(canvas, -width * 2.2, -length * 0.5, 0.4, 2.5, 0.2, sBenchPaint);
    _drawBench(canvas, -width * 2.2, length * 0.5, 0.4, 2.5, 0.2, sBenchPaint);
    // Right side benches
    _drawBench(canvas, width * 2.2, -length * 0.5, 0.4, 2.5, 0.2, sBenchPaint);
    _drawBench(canvas, width * 2.2, length * 0.5, 0.4, 2.5, 0.2, sBenchPaint);
  }
}

class HitEffectComponent extends Component {
  HitEffectComponent({
    required this.center,
    required this.isSmash,
    required this.scale,
  });

  final Offset center;
  final bool isSmash;
  final double scale;

  double _lifetime = 0.0;
  static const double _maxLifetime = 0.22; // 220ms

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _maxLifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / _maxLifetime).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // 1. Expanding shockwave ring
    final ringRadius = (isSmash ? 20.0 : 12.0) * scale + progress * (isSmash ? 30.0 : 18.0) * scale;
    final ringPaint = Paint()
      ..color = (isSmash ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF)).withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSmash ? 3.5 : 2.0) * (1.0 - progress * 0.5) * scale;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 2. 6 radiating sparks
    final sparkPaint = Paint()
      ..color = (isSmash ? const Color(0xFFFF9800) : const Color(0xFFFFEB3B)).withAlpha(alpha)
      ..style = PaintingStyle.fill;

    final sparkDistance = 10.0 * scale + progress * (isSmash ? 32.0 : 20.0) * scale;
    final sparkRadius = (isSmash ? 3.0 : 2.0) * (1.0 - progress) * scale;

    if (sparkRadius > 0.5) {
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60) * 3.1415926535 / 180;
        final sparkOffset = Offset(
          center.dx + sparkDistance * math.cos(angle),
          center.dy + sparkDistance * math.sin(angle),
        );
        canvas.drawCircle(sparkOffset, sparkRadius, sparkPaint);
      }
    }
  }
}

class DashEffectComponent extends Component {
  DashEffectComponent({
    required this.center,
    required this.scale,
    required this.isPlayer,
  });

  final Offset center;
  final double scale;
  final bool isPlayer;

  double _lifetime = 0.0;
  static const double _maxLifetime = 0.30;

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / _maxLifetime).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress) * 200).round().clamp(0, 255);
    final color = isPlayer ? const Color(0xFF00B0FF) : const Color(0xFFFF5252);

    // Expanding ring
    final ringRadius = 22.0 * scale + progress * 38.0 * scale;
    final ringPaint = Paint()
      ..color = color.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * (1.0 - progress) * scale;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Speed streaks
    final streakPaint = Paint()
      ..color = color.withAlpha((alpha * 0.6).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 + 20) * math.pi / 180;
      final len = (20.0 + i * 8.0) * scale * (1.0 - progress * 0.5);
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * 20 * scale, center.dy + math.sin(angle) * 20 * scale),
        Offset(center.dx + math.cos(angle) * (20 * scale + len), center.dy + math.sin(angle) * (20 * scale + len)),
        streakPaint,
      );
    }
  }
}