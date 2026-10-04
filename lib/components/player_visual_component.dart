import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_debug_config.dart';
import '../game_simulation.dart';
import '../models/paddle_item.dart';
import '../pickleball_flame_game.dart';
import '../settings_manager.dart';

/// Flame visual component for rendering the player character, animation frames,
/// electric cyan familiar paddle orbit, and debug reach hitboxes.
class PlayerVisualComponent extends Component {
  PlayerVisualComponent(this.game);

  final PickleballFlameGame game;
  double animTimer = 0.0;
  int facingRow = 0; // 0=Up, 1=Left, 2=Down, 3=Right
  double _swingTimer = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    animTimer += dt;

    if (game.isSwinging) {
      _swingTimer = (_swingTimer + dt).clamp(0.0, 0.18);
    } else {
      _swingTimer = 0.0;
    }

    // Check effective input (from keyboard or joystick) and simulation velocity
    double moveX = game.effectiveInputX;
    double moveY = game.effectiveInputY;

    if (moveX.abs() < 0.05 && moveY.abs() < 0.05) {
      moveX = game.simulation.playerVelocityX;
      moveY = game.simulation.playerVelocityY;
    }

    // Update facing direction dynamically based on movement
    if (moveX.abs() > 0.01 || moveY.abs() > 0.01) {
      if (moveX.abs() > moveY.abs()) {
        facingRow = moveX > 0 ? 3 : 1; // 3 = Right, 1 = Left
      } else {
        facingRow = moveY > 0
            ? 2
            : 0; // 2 = Down (front), 0 = Up (back toward net)
      }
    }
  }

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

    final shadowPaintFloor = Paint()
      ..color = const Color(0x40000000)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 10 * scale),
        width: 45 * scale,
        height: 18 * scale,
      ),
      shadowPaintFloor,
    );

    final active = simulation.ball.velocityY > 0;
    final teamRingPaint = Paint()
      ..color = const Color(0xFFFFB84D).withValues(alpha: active ? 0.72 : 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (active ? 2.4 : 1.4) * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 10 * scale),
        width: 51 * scale,
        height: 21 * scale,
      ),
      teamRingPaint,
    );

    final vx = game.simulation.playerVelocityX;
    final vy = game.simulation.playerVelocityY;
    final bool isMoving =
        (vx.abs() > 0.005 || vy.abs() > 0.005) ||
        (game.effectiveInputX.abs() > 0.08 ||
            game.effectiveInputY.abs() > 0.08);

    int validFrames = 1;
    double speed = 0.1;
    int baseRow = 8; // Default walk rows (8-11)

    if (game.isSwinging) {
      baseRow = 12; // Slash rows (12-15)
      validFrames = 6;
      speed = 0.05;
    } else if (game.isDashing) {
      baseRow = 38; // Run rows (38-41)
      validFrames = 8;
      speed = 0.06;
    } else if (isMoving) {
      baseRow = 8; // Walk rows (8-11)
      validFrames = 9;
      speed = 0.08;
    } else {
      baseRow = 22; // Idle breathing rows (22-25)
      validFrames = 2;
      speed = 0.5;
    }

    // Unified LPC sheet has 18 columns and 66 rows
    final frameWidth = game.unifiedSprite.width / 18.0;
    final frameHeight = game.unifiedSprite.height / 66.0;

    int frameCol = (animTimer / speed).floor() % validFrames;
    int frameRow = baseRow + facingRow;

    final drawWidth = frameWidth * 1.6 * scale;
    final drawHeight = frameHeight * 1.6 * scale;

    final src = Rect.fromLTWH(
      frameCol * frameWidth,
      frameRow * frameHeight,
      frameWidth,
      frameHeight,
    );
    final dst = Rect.fromCenter(
      center: center.translate(0, -15 * scale),
      width: drawWidth,
      height: drawHeight,
    );

    // Calculate ball screen position for kinetic strike
    final ballPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final ballScreenPos = Offset(
      (ballPoint.x + 1.0) / 2.0 * game.size.x,
      (ballPoint.y + 1.0) / 2.0 * game.size.y,
    );

    final isBotVsBot = game.simulation.gameMode == GameMode.botVsBot;
    final equipped = isBotVsBot
        ? game.bottomBotPaddle
        : PaddleCatalog.getById(SettingsManager().equippedPaddleId);
    // Keep compositing depth synchronized with the selected familiar's orbit.
    final orbitAngle =
        animTimer * kineticFamiliarOrbitSpeed(equipped.resolvedDesign);
    final isBehind = math.sin(orbitAngle) < -0.15 && !game.isSwinging;
    void drawPlayerFamiliarPaddle() {
      drawKineticPaddle(
        canvas: canvas,
        charCenter: center,
        scale: scale,
        facingRow: facingRow,
        animTimer: animTimer,
        isSwinging: game.isSwinging,
        swingProgress: (_swingTimer / 0.18).clamp(0.0, 1.0),
        ballScreenPos: ballScreenPos,
        paddleFaceColor: equipped.paddleFaceColor,
        paddleRimColor: equipped.paddleRimColor,
        energyColor: equipped.energyColor,
        sweetSpotColor: equipped.sweetSpotColor,
        design: equipped.resolvedDesign,
      );
    }

    if (isBehind) {
      drawPlayerFamiliarPaddle();
      canvas.drawImageRect(game.unifiedSprite, src, dst, Paint());
    } else {
      canvas.drawImageRect(game.unifiedSprite, src, dst, Paint());
      drawPlayerFamiliarPaddle();
    }

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

    if (GameDebugConfig.showHitboxes) _drawHitbox(canvas, simulation);
  }

  void _drawHitbox(Canvas canvas, GameSimulation sim) {
    Offset proj(double x, double y, double z) {
      final p = sim.camera.project(x: x, y: y, elevation: z);
      return Offset(
        (p.x + 1.0) / 2.0 * game.size.x,
        (p.y + 1.0) / 2.0 * game.size.y,
      );
    }

    final pX = sim.playerX;
    final pY = sim.playerY;
    final rX = sim.playerHitRadiusX;
    final frontY = sim.playerHitFrontY;
    final backY = sim.playerHitBackY;
    final zMin = sim.playerHitZMin;
    final zMax = sim.playerHitZMax;
    final zMid = (zMin + zMax) / 2.0;

    // Player faces net in -Y direction
    final yFront = pY - frontY;
    final yBack = pY + backY;

    final pathMin = Path()
      ..moveTo(proj(pX - rX, yFront, zMin).dx, proj(pX - rX, yFront, zMin).dy)
      ..lineTo(proj(pX + rX, yFront, zMin).dx, proj(pX + rX, yFront, zMin).dy)
      ..lineTo(proj(pX + rX, yBack, zMin).dx, proj(pX + rX, yBack, zMin).dy)
      ..lineTo(proj(pX - rX, yBack, zMin).dx, proj(pX - rX, yBack, zMin).dy)
      ..close();

    final pathMid = Path()
      ..moveTo(proj(pX - rX, yFront, zMid).dx, proj(pX - rX, yFront, zMid).dy)
      ..lineTo(proj(pX + rX, yFront, zMid).dx, proj(pX + rX, yFront, zMid).dy)
      ..lineTo(proj(pX + rX, yBack, zMid).dx, proj(pX + rX, yBack, zMid).dy)
      ..lineTo(proj(pX - rX, yBack, zMid).dx, proj(pX - rX, yBack, zMid).dy)
      ..close();

    final pathMax = Path()
      ..moveTo(proj(pX - rX, yFront, zMax).dx, proj(pX - rX, yFront, zMax).dy)
      ..lineTo(proj(pX + rX, yFront, zMax).dx, proj(pX + rX, yFront, zMax).dy)
      ..lineTo(proj(pX + rX, yBack, zMax).dx, proj(pX + rX, yBack, zMax).dy)
      ..lineTo(proj(pX - rX, yBack, zMax).dx, proj(pX - rX, yBack, zMax).dy)
      ..close();

    final paint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final midPaint = Paint()
      ..color = const Color(0x5500E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fillPaint = Paint()
      ..color = const Color(0x2200E5FF)
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathMin, paint);
    canvas.drawPath(pathMid, midPaint);
    canvas.drawPath(pathMax, paint);
    canvas.drawPath(pathMax, fillPaint);

    canvas.drawLine(
      proj(pX - rX, yFront, zMin),
      proj(pX - rX, yFront, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX + rX, yFront, zMin),
      proj(pX + rX, yFront, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX + rX, yBack, zMin),
      proj(pX + rX, yBack, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX - rX, yBack, zMin),
      proj(pX - rX, yBack, zMax),
      paint,
    );
  }
}
