import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_debug_config.dart';
import '../game_simulation.dart';
import '../pickleball_flame_game.dart';

/// Flame visual component for rendering the bot opponent, its animated sprite sheet frames,
/// crimson familiar paddle orbit, and debug reach hitboxes.
class BotVisualComponent extends Component {
  BotVisualComponent(this.game);

  final PickleballFlameGame game;
  double animTimer = 0.0;
  int facingRow = 2; // Default facing Down (front towards player)
  double _prevBotX = 0;
  double _prevBotY = -0.75;
  double _smoothDx = 0.0;
  double _smoothDy = 0.0;
  bool _isMoving = false;
  double _swingTimer = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    animTimer += dt;

    if (game.isBotSwinging) {
      _swingTimer = (_swingTimer + dt).clamp(0.0, 0.18);
    } else {
      _swingTimer = 0.0;
    }

    final simulation = game.simulation;
    final isPractice = simulation.gameMode == GameMode.freeRoamPractice;
    if (isPractice) return;

    final rawDx = simulation.botX - _prevBotX;
    final rawDy = simulation.botY - _prevBotY;
    _prevBotX = simulation.botX;
    _prevBotY = simulation.botY;

    // Exponential smoothing filter to prevent single-frame flickering
    _smoothDx = _smoothDx * 0.75 + rawDx * 0.25;
    _smoothDy = _smoothDy * 0.75 + rawDy * 0.25;

    final speed = (dt > 0)
        ? (math.sqrt(_smoothDx * _smoothDx + _smoothDy * _smoothDy) / dt)
        : 0.0;
    _isMoving = speed > 0.04;

    if (_isMoving) {
      // Require clear horizontal dominance and significant speed before flipping left/right
      if (_smoothDx.abs() > _smoothDy.abs() * 1.3 && _smoothDx.abs() > 0.003) {
        facingRow = _smoothDx > 0 ? 3 : 1; // 3 = Right, 1 = Left
      } else if (_smoothDy.abs() > 0.003) {
        facingRow = _smoothDy > 0
            ? 2
            : 0; // 2 = Down (towards player), 0 = Up (away)
      }
    } else {
      facingRow = 2; // Face towards player by default when idle
    }
  }

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
    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 10 * scale),
        width: 40 * scale,
        height: 16 * scale,
      ),
      shadowPaint,
    );

    if (!isPractice) {
      final active = simulation.ball.velocityY < 0;
      final teamRingPaint = Paint()
        ..color = const Color(0xFFFF5D73)
            .withValues(alpha: active ? 0.72 : 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (active ? 2.4 : 1.4) * scale;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, 10 * scale),
          width: 46 * scale,
          height: 19 * scale,
        ),
        teamRingPaint,
      );
    }

    if (isPractice) {
      // Draw ball machine
      final machinePaint = Paint()
        ..color = const Color(0xFF455A64)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, -10 * scale),
            width: 30 * scale,
            height: 40 * scale,
          ),
          const Radius.circular(8),
        ),
        machinePaint,
      );

      // Draw nozzle
      final nozzlePaint = Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center.translate(0, -15 * scale),
        12 * scale,
        nozzlePaint,
      );

      final indicatorPaint = Paint()
        ..color = (simulation.ballMachineTimer < 30)
            ? const Color(0xFFFF5252)
            : const Color(0xFF69F0AE)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center.translate(0, -15 * scale),
        6 * scale,
        indicatorPaint,
      );
    } else {
      int validFrames = 1;
      double speed = 0.1;
      int baseRow = 8; // Default walk rows (8-11)

      if (game.isBotSwinging) {
        baseRow = 12; // Slash rows (12-15)
        validFrames = 6;
        speed = 0.04;
      } else if (_isMoving) {
        baseRow = 8; // Walk rows (8-11)
        validFrames = 9;
        speed = 0.08;
      } else {
        baseRow = 22; // Idle breathing rows (22-25)
        validFrames = 2;
        speed = 0.5;
      }

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

      // Draw bot sprite with opponent crimson aura / tint
      final botSpritePaint = Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0x35E53935),
          BlendMode.srcATop,
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

      // Familiar orbit depth check (passes behind character when sin(orbitAngle) < -0.15)
      final orbitAngle = animTimer * 2.6;
      final isBehind = math.sin(orbitAngle) < -0.15 && !game.isBotSwinging;

      final botPaddle = game.topBotPaddle;
      void drawBotFamiliarPaddle() {
        drawKineticPaddle(
          canvas: canvas,
          charCenter: center,
          scale: scale,
          facingRow: facingRow,
          animTimer: animTimer,
          isSwinging: game.isBotSwinging,
          swingProgress: (_swingTimer / 0.18).clamp(0.0, 1.0),
          ballScreenPos: ballScreenPos,
          paddleFaceColor: botPaddle.paddleFaceColor,
          paddleRimColor: botPaddle.paddleRimColor,
          energyColor: botPaddle.energyColor,
          sweetSpotColor: botPaddle.sweetSpotColor,
        );
      }

      if (isBehind) {
        drawBotFamiliarPaddle();
        canvas.drawImageRect(game.unifiedSprite, src, dst, botSpritePaint);
      } else {
        canvas.drawImageRect(game.unifiedSprite, src, dst, botSpritePaint);
        drawBotFamiliarPaddle();
      }
    }

    if (!isPractice && GameDebugConfig.showHitboxes) {
      _drawHitbox(canvas, simulation);
    }
  }

  void _drawHitbox(Canvas canvas, GameSimulation sim) {
    Offset proj(double x, double y, double z) {
      final p = sim.camera.project(x: x, y: y, elevation: z);
      return Offset(
        (p.x + 1.0) / 2.0 * game.size.x,
        (p.y + 1.0) / 2.0 * game.size.y,
      );
    }

    final pX = sim.botX;
    final pY = sim.botY;
    final rX = sim.botHitRadiusX;
    final frontY = sim.botHitFrontY;
    final backY = sim.botHitBackY;
    final zMin = sim.botHitZMin;
    final zMax = sim.botHitZMax;
    final zMid = (zMin + zMax) / 2.0;

    // Bot faces net in +Y direction
    final yFront = pY + frontY;
    final yBack = pY - backY;

    final pathMin = Path()
      ..moveTo(proj(pX - rX, yBack, zMin).dx, proj(pX - rX, yBack, zMin).dy)
      ..lineTo(proj(pX + rX, yBack, zMin).dx, proj(pX + rX, yBack, zMin).dy)
      ..lineTo(proj(pX + rX, yFront, zMin).dx, proj(pX + rX, yFront, zMin).dy)
      ..lineTo(proj(pX - rX, yFront, zMin).dx, proj(pX - rX, yFront, zMin).dy)
      ..close();

    final pathMid = Path()
      ..moveTo(proj(pX - rX, yBack, zMid).dx, proj(pX - rX, yBack, zMid).dy)
      ..lineTo(proj(pX + rX, yBack, zMid).dx, proj(pX + rX, yBack, zMid).dy)
      ..lineTo(proj(pX + rX, yFront, zMid).dx, proj(pX + rX, yFront, zMid).dy)
      ..lineTo(proj(pX - rX, yFront, zMid).dx, proj(pX - rX, yFront, zMid).dy)
      ..close();

    final pathMax = Path()
      ..moveTo(proj(pX - rX, yBack, zMax).dx, proj(pX - rX, yBack, zMax).dy)
      ..lineTo(proj(pX + rX, yBack, zMax).dx, proj(pX + rX, yBack, zMax).dy)
      ..lineTo(proj(pX + rX, yFront, zMax).dx, proj(pX + rX, yFront, zMax).dy)
      ..lineTo(proj(pX - rX, yFront, zMax).dx, proj(pX - rX, yFront, zMax).dy)
      ..close();

    final paint = Paint()
      ..color = const Color(0xAA00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final midPaint = Paint()
      ..color = const Color(0x5500FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fillPaint = Paint()
      ..color = const Color(0x2200FF00)
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathMin, paint);
    canvas.drawPath(pathMid, midPaint);
    canvas.drawPath(pathMax, paint);
    canvas.drawPath(pathMax, fillPaint);

    canvas.drawLine(
      proj(pX - rX, yBack, zMin),
      proj(pX - rX, yBack, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX + rX, yBack, zMin),
      proj(pX + rX, yBack, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX + rX, yFront, zMin),
      proj(pX + rX, yFront, zMax),
      paint,
    );
    canvas.drawLine(
      proj(pX - rX, yFront, zMin),
      proj(pX - rX, yFront, zMax),
      paint,
    );
  }
}
