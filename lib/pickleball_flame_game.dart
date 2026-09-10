import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect, Size;

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

  @override
  Future<void> onLoad() async {
    await add(BallVisualComponent(this));
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
    final court = _courtRect(Size(game.size.x, game.size.y));
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

  Rect _courtRect(Size size) {
    final aspectRatio = 9 / 16;
    final aspectWidth = size.width / size.height > aspectRatio
        ? size.height * aspectRatio
        : size.width;
    final aspectHeight = aspectWidth / aspectRatio;
    return Rect.fromLTWH(
      (size.width - aspectWidth) / 2 + 12,
      (size.height - aspectHeight) / 2 + 12,
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
}