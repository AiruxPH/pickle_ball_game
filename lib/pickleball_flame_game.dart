import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

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

    _timeAccumulator += dt.clamp(0, 0.1);
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

    while (_timeAccumulator >= fixedStep) {
      final rallyEnd = simulation.update(
        joystickX: currentInputX.clamp(-1, 1),
        joystickY: currentInputY.clamp(-1, 1),
      );
      _timeAccumulator -= fixedStep;
      if (rallyEnd != null) {
        stop();
        onRallyEnd?.call(rallyEnd);
        break;
      }
    }
  }
}

class BallVisualComponent extends Component {
  BallVisualComponent(this.game);

  final PickleballFlameGame game;

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

    final shadowPaint = Paint()
      ..color = const Color(0x59000000)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: 18 * shadowScale,
        height: 8 * shadowScale,
      ),
      shadowPaint,
    );

    final ballPaint = Paint()
      ..color = const Color(0xFFD4E157)
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
    final point = simulation.camera.project(
      x: simulation.botX,
      y: simulation.botY,
    );
    final scale = point.scale;
    final center = Offset(
      (point.x + 1.0) / 2.0 * game.size.x,
      (point.y + 1.0) / 2.0 * game.size.y,
    );
    final paint = Paint()..color = const Color(0xFFFF5252);
    canvas.drawCircle(center, 22.5 * scale, paint);
    final iconPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    canvas.drawCircle(center, 10 * scale, iconPaint);
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
    final playerPaint = Paint()..color = bodyColor;
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

    final racketPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;
    final racketCenter = center.translate(
      24 * scale,
      (game.isSwinging ? -10 : 2) * scale,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: racketCenter,
        width: 14 * scale,
        height: 32 * scale,
      ),
      racketPaint,
    );
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

  @override
  void render(Canvas canvas) {
    final width = GameSimulation.courtWidth;
    final length = GameSimulation.courtLength;
    final kDepth = 0.3; // Kitchen depth

    // Draw grass (oversized floor)
    final floorExtW = width * 2.5;
    final floorExtL = length * 2.5;
    final grassPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawPath(
      _quad(-floorExtW, -floorExtL, floorExtW, -floorExtL, floorExtW, floorExtL, -floorExtW, floorExtL),
      grassPaint,
    );

    // Court outline
    final linePaint = Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawPath(
      _quad(-width, -length, width, -length, width, length, -width, length),
      linePaint,
    );

    // Center line (from baseline to kitchen line)
    // Bot side (-length to -kDepth)
    canvas.drawLine(_proj(0, -length), _proj(0, -kDepth), linePaint);
    // Player side (kDepth to length)
    canvas.drawLine(_proj(0, kDepth), _proj(0, length), linePaint);

    // Kitchen lines
    canvas.drawLine(_proj(-width, -kDepth), _proj(width, -kDepth), linePaint);
    canvas.drawLine(_proj(-width, kDepth), _proj(width, kDepth), linePaint);

    // Kitchen paint
    final kitchenPaint = Paint()..color = const Color(0x1FFFD54F)..style = PaintingStyle.fill;
    canvas.drawPath(
      _quad(-width, -kDepth, width, -kDepth, width, kDepth, -width, kDepth),
      kitchenPaint,
    );

    // Net
    final netShadowPaint = Paint()..color = const Color(0x33000000)..strokeWidth = 6;
    // draw shadow at z=0, slightly offset
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(width * 1.1, 0, 0), netShadowPaint);

    final netHeight = 0.18;
    final netPaint = Paint()..color = const Color(0xDDFFFFFF)..strokeWidth = 3..style = PaintingStyle.stroke;
    final netMeshPaint = Paint()..color = const Color(0x55FFFFFF)..style = PaintingStyle.fill;
    
    // Net mesh
    final netPath = Path()
      ..moveTo(_proj(-width * 1.1, 0, 0).dx, _proj(-width * 1.1, 0, 0).dy)
      ..lineTo(_proj(width * 1.1, 0, 0).dx, _proj(width * 1.1, 0, 0).dy)
      ..lineTo(_proj(width * 1.1, 0, netHeight).dx, _proj(width * 1.1, 0, netHeight).dy)
      ..lineTo(_proj(-width * 1.1, 0, netHeight).dx, _proj(-width * 1.1, 0, netHeight).dy)
      ..close();
    canvas.drawPath(netPath, netMeshPaint);

    // Bottom of net
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(width * 1.1, 0, 0), netPaint);
    // Top of net
    canvas.drawLine(_proj(-width * 1.1, 0, netHeight), _proj(width * 1.1, 0, netHeight), netPaint);
    // Posts
    canvas.drawLine(_proj(-width * 1.1, 0, 0), _proj(-width * 1.1, 0, netHeight), netPaint);
    canvas.drawLine(_proj(width * 1.1, 0, 0), _proj(width * 1.1, 0, netHeight), netPaint);
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