import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect;

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

  void stop() {
    isPlaying = false;
    inputX = 0;
    inputY = 0;
  }

  @override
  void update(double dt) {
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
    final court = _courtRect(game.size);
    final shadowPoint = simulation.projection.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
    );
    final ballPoint = simulation.projection.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final shadowCenter = _screenPoint(court, shadowPoint.x, shadowPoint.y);
    final ballCenter = _screenPoint(court, ballPoint.x, ballPoint.y);
    final depthScale = simulation.projection.depthScaleAt(simulation.ball.y);
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

Rect _courtRect(Vector2 size) {
  final aspectRatio = 9 / 16;
  final aspectWidth = size.x / size.y > aspectRatio
      ? size.y * aspectRatio
      : size.x;
  final aspectHeight = aspectWidth / aspectRatio;
  return Rect.fromLTWH(
    (size.x - aspectWidth) / 2 + 12,
    (size.y - aspectHeight) / 2 + 12,
    aspectWidth - 24,
    aspectHeight - 24,
  );
}

Offset _screenPoint(Rect court, double x, double y) {
  return Offset(
    court.center.dx + x * court.width / 2,
    court.center.dy + y * court.height / 2,
  );
}

class BotVisualComponent extends Component {
  BotVisualComponent(this.game);

  final PickleballFlameGame game;

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final court = _courtRect(game.size);
    final point = simulation.projection.project(
      x: simulation.botX,
      y: simulation.botY,
    );
    final scale = simulation.projection.depthScaleAt(simulation.botY);
    final center = _screenPoint(court, point.x, point.y);
    final paint = Paint()..color = const Color(0xFFFF5252);
    canvas.drawCircle(center, 22.5 * scale, paint);
    final iconPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 10 * scale, iconPaint);
  }
}

class PlayerVisualComponent extends Component {
  PlayerVisualComponent(this.game);

  final PickleballFlameGame game;

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final court = _courtRect(game.size);
    final point = simulation.projection.project(
      x: simulation.playerX,
      y: simulation.playerY,
    );
    final scale = simulation.projection.depthScaleAt(simulation.playerY);
    final center = _screenPoint(court, point.x, point.y);
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

  @override
  void render(Canvas canvas) {
    final court = _courtRect(game.size);
    final grassPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(court, grassPaint);

    final stripePaint = Paint()
      ..color = const Color(0x52388E3C)
      ..style = PaintingStyle.fill;
    for (var index = 0; index < 10; index++) {
      final stripe = Rect.fromLTWH(
        court.left + court.width * index / 10,
        court.top,
        court.width / 20,
        court.height,
      );
      canvas.drawRect(stripe, stripePaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final centerX = court.center.dx;
    final kitchenTop = court.top + court.height * 0.35;
    final kitchenBottom = court.top + court.height * 0.65;

    canvas.drawRect(court, linePaint);
    canvas.drawLine(
      Offset(court.left, kitchenTop),
      Offset(court.right, kitchenTop),
      linePaint,
    );
    canvas.drawLine(
      Offset(court.left, kitchenBottom),
      Offset(court.right, kitchenBottom),
      linePaint,
    );
    canvas.drawLine(Offset(centerX, court.top), Offset(centerX, kitchenTop), linePaint);
    canvas.drawLine(Offset(centerX, kitchenBottom), Offset(centerX, court.bottom), linePaint);

    final kitchenPaint = Paint()
      ..color = const Color(0x1FFFD54F)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(court.left, kitchenTop, court.right, kitchenBottom),
      kitchenPaint,
    );

    final netShadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 10;
    canvas.drawLine(
      Offset(court.left, court.center.dy + 7),
      Offset(court.right, court.center.dy + 7),
      netShadowPaint,
    );

    final netPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(court.left, court.center.dy),
      Offset(court.right, court.center.dy),
      netPaint,
    );
    canvas.drawCircle(Offset(court.left, court.center.dy), 6, netPaint);
    canvas.drawCircle(Offset(court.right, court.center.dy), 6, netPaint);
  }
}