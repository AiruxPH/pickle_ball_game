import 'dart:math' as math;
import 'dart:ui'
    show
        Canvas,
        Color,
        Offset,
        Paint,
        PaintingStyle,
        Path,
        Rect,
        Gradient,
        RRect,
        Radius,
        MaskFilter,
        BlurStyle,
        Image,
        ColorFilter,
        BlendMode;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'game_debug_config.dart';
import 'game_simulation.dart';
import 'pickleball_rules.dart';
import 'match_state.dart';
import 'settings_manager.dart';

class PickleballFlameGame extends FlameGame {
  PickleballFlameGame({GameSimulation? simulation, this.onRallyEnd})
    : simulation = simulation ?? GameSimulation();

  static const double fixedStep = 0.025;

  final GameSimulation simulation;
  late final Image unifiedSprite;
  void Function(RallyEnd event)? onRallyEnd;
  double inputX = 0;
  double inputY = 0;
  double effectiveInputX = 0;
  double effectiveInputY = 0;
  double _timeAccumulator = 0;
  bool isPlaying = false;
  bool isSwinging = false;
  bool isBotSwinging = false;
  bool isDashing = false; // Player dash VFX state
  double _dashVfxTimer = 0.0;

  void spawnDashEffect({
    required double x,
    required double y,
    required bool isPlayer,
  }) {
    if (!SettingsManager().showEffects) return;
    final point = simulation.camera.project(x: x, y: y);
    final center = Offset(
      (point.x + 1.0) / 2.0 * size.x,
      (point.y + 1.0) / 2.0 * size.y,
    );
    add(
      DashEffectComponent(
        center: center,
        scale: point.scale,
        isPlayer: isPlayer,
      ),
    );
    if (isPlayer) {
      isDashing = true;
      _dashVfxTimer = 0.25;
    }
  }

  @override
  Future<void> onLoad() async {
    // Load external sprite assets (transparent PNGs)
    unifiedSprite = await images.load('character-spritesheet (2).png');

    await add(CourtVisualComponent(this));
    await add(BallVisualComponent(this));
    await add(BotVisualComponent(this));
    await add(PlayerVisualComponent(this));
  }

  void start() {
    isPlaying = true;
  }

  void spawnHitEffect({required bool isSmash}) {
    if (!SettingsManager().showEffects) return;
    final point = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final center = Offset(
      (point.x + 1.0) / 2.0 * size.x,
      (point.y + 1.0) / 2.0 * size.y,
    );
    add(
      HitEffectComponent(center: center, isSmash: isSmash, scale: point.scale),
    );

    // Add camera shake for impact
    if (!SettingsManager().reducedMotion) {
      if (isSmash) {
        simulation.camera.addShake(1.0);
      } else {
        simulation.camera.addShake(0.3);
      }
    }
  }

  void spawnBounceEffect() {
    if (!SettingsManager().showEffects) return;
    final point = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
    );
    final center = Offset(
      (point.x + 1.0) / 2.0 * size.x,
      (point.y + 1.0) / 2.0 * size.y,
    );
    add(BounceEffectComponent(center: center, scale: point.scale));
  }

  void stop() {
    isPlaying = false;
    inputX = 0;
    inputY = 0;
    effectiveInputX = 0;
    effectiveInputY = 0;
  }

  @override
  void update(double dt) {
    if (hasLayout) {
      simulation.camera.updateSize(size.x, size.y);
    }
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

    // Spectate input is reserved for the free-roam camera. It must never be
    // forwarded as movement input to either autonomous bot.
    if (simulation.gameMode == GameMode.botVsBot &&
        simulation.camera.mode != CameraMode.freeRoam) {
      currentInputX = 0;
      currentInputY = 0;
    }

    effectiveInputX = currentInputX.clamp(-1.0, 1.0);
    effectiveInputY = currentInputY.clamp(-1.0, 1.0);

    while (_timeAccumulator >= fixedStep) {
      final rallyEnd = simulation.update(
        joystickX: effectiveInputX,
        joystickY: effectiveInputY,
      );
      _timeAccumulator -= fixedStep;

      for (final event in simulation.drainEvents()) {
        switch (event.type) {
          case GameplayEventType.botHit:
            if (event.side == MatchSide.player) {
              isSwinging = true;
              playerBotSwingTimer = 0.15;
            } else {
              isBotSwinging = true;
              botSwingTimer = 0.15;
            }
            if (!SettingsManager().reducedMotion) {
              simulation.camera.addShake(event.isSmash ? 0.7 : 0.4);
            }
            break;
          case GameplayEventType.playerHit:
            break;
          case GameplayEventType.bounce:
            spawnBounceEffect();
            break;
          case GameplayEventType.netFault:
            spawnHitEffect(isSmash: false);
            break;
          case GameplayEventType.outOfBounds:
          case GameplayEventType.doubleBounce:
          case GameplayEventType.rallyEnd:
            break;
        }
      }

      if (rallyEnd != null) {
        onRallyEnd?.call(rallyEnd);
      }
    }

    if (botSwingTimer > 0) {
      botSwingTimer -= dt;
      if (botSwingTimer <= 0) isBotSwinging = false;
    }
    if (playerBotSwingTimer > 0) {
      playerBotSwingTimer -= dt;
      if (playerBotSwingTimer <= 0) isSwinging = false;
    }
    if (_dashVfxTimer > 0) {
      _dashVfxTimer -= dt;
      if (_dashVfxTimer <= 0) isDashing = false;
    }
  }

  double botSwingTimer = 0;
  double playerBotSwingTimer = 0;
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

    // Only add to trail if ball is moving fast enough and effects are enabled.
    if (SettingsManager().showEffects &&
        (simulation.ball.velocityX.abs() > 0.005 ||
            simulation.ball.velocityY.abs() > 0.005)) {
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
      final opacity = progress * 0.34;
      final sizeMult = 0.35 + progress * 0.65;
      final trailPaint = Paint()
        ..color = Color.fromRGBO(216, 240, 106, opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(_trail[i], 8 * _trailScales[i] * sizeMult, trailPaint);
    }

    final glowPaint = Paint()
      ..color = const Color(0x66D8F06A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(ballCenter, 14 * ballScale, glowPaint);

    final ballPaint = Paint()
      ..shader = Gradient.radial(
        ballCenter.translate(-3 * ballScale, -3 * ballScale),
        11 * ballScale,
        [
          const Color(0xFFF4FF81),
          const Color(0xFFD4E157),
          const Color(0xFF9E9D24),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballCenter, 11 * ballScale, ballPaint);

    final outlinePaint = Paint()
      ..color = SettingsManager().highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xE6F8FFD0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (SettingsManager().highContrast ? 2.8 : 1.4) * ballScale;
    canvas.drawCircle(ballCenter, 11 * ballScale, outlinePaint);

    // A few high-contrast perforations keep the projectile readable as a
    // pickleball instead of a generic glowing orb.
    final holePaint = Paint()..color = const Color(0xAA76851D);
    canvas.drawCircle(
      ballCenter.translate(-3.2 * ballScale, -2.2 * ballScale),
      1.25 * ballScale,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter.translate(3.4 * ballScale, 1.6 * ballScale),
      1.05 * ballScale,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter.translate(-1.0 * ballScale, 4.0 * ballScale),
      0.9 * ballScale,
      holePaint,
    );
  }
}

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
      canvas.drawImageRect(game.unifiedSprite, src, dst, botSpritePaint);

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

      // Draw Bot's Floating / Kinetic Paddle (Hot Crimson & Obsidian)
      _drawKineticPaddle(
        canvas: canvas,
        charCenter: center,
        scale: scale,
        facingRow: facingRow,
        animTimer: animTimer,
        isSwinging: game.isBotSwinging,
        swingProgress: (_swingTimer / 0.18).clamp(0.0, 1.0),
        ballScreenPos: ballScreenPos,
        paddleFaceColor: const Color(0xFFFF1744), // Crimson neon
        paddleRimColor: const Color(0xFF212121), // Obsidian black
        energyColor: const Color(0xFFFF4081), // Hot pink energy
        sweetSpotColor: const Color(0xFFFFD700), // Golden sweet spot
      );
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

    // Scale up the single frame so it's a good size on the court
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

    // Draw the single unified sprite
    canvas.drawImageRect(game.unifiedSprite, src, dst, Paint());

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

    // Draw Player's Floating / Kinetic Paddle (Electric Neon Cyan)
    _drawKineticPaddle(
      canvas: canvas,
      charCenter: center,
      scale: scale,
      facingRow: facingRow,
      animTimer: animTimer,
      isSwinging: game.isSwinging,
      swingProgress: (_swingTimer / 0.18).clamp(0.0, 1.0),
      ballScreenPos: ballScreenPos,
      paddleFaceColor: const Color(0xFF00E5FF), // Electric Neon Cyan
      paddleRimColor: const Color(0xFF102A43), // Dark Graphite Navy
      energyColor: const Color(0xFF00E5FF), // Cyan Energy
      sweetSpotColor: const Color(0xFFFFFFFF), // Pure White sweet spot
    );

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

void _drawKineticPaddle({
  required Canvas canvas,
  required Offset charCenter,
  required double scale,
  required int facingRow,
  required double animTimer,
  required bool isSwinging,
  required double swingProgress,
  required Offset ballScreenPos,
  required Color paddleFaceColor,
  required Color paddleRimColor,
  required Color energyColor,
  required Color sweetSpotColor,
}) {
  canvas.save();

  // Hand anchor relative to character center
  Offset handOffset;
  double baseAngle;

  switch (facingRow) {
    case 0: // Facing Up (towards net - back of character)
      handOffset = Offset(16 * scale, -10 * scale);
      baseAngle = -0.3;
      break;
    case 1: // Facing Left
      handOffset = Offset(-14 * scale, -8 * scale);
      baseAngle = -0.7;
      break;
    case 2: // Facing Down (towards camera - front of character)
      handOffset = Offset(14 * scale, -6 * scale);
      baseAngle = 0.4;
      break;
    case 3: // Facing Right
    default:
      handOffset = Offset(14 * scale, -8 * scale);
      baseAngle = 0.7;
      break;
  }

  final handPos = charCenter + handOffset;

  // Floating Hover Position (floating magnetically near dominant side)
  final hoverBob = math.sin(animTimer * 4.5) * (3.0 * scale);
  final hoverOffset =
      handOffset +
      Offset(6 * scale * (facingRow == 1 ? -1 : 1), -4 * scale + hoverBob);
  final hoverPos = charCenter + hoverOffset;

  Offset paddlePos;
  double paddleAngle;
  double flightCurve = 0.0;

  if (isSwinging && swingProgress > 0) {
    // Kinetic flight curve: 0.0 -> 1.0 (peak extension at ball) -> 0.0 (return)
    flightCurve = math.sin(swingProgress.clamp(0.0, 1.0) * math.pi);

    final diff = ballScreenPos - charCenter;
    final dist = diff.distance;

    // The sweet spot of the elongated paddle is located at the center of the blade
    // (-19 * scale along the local -Y axis).
    final sweetSpotOffset = 19.0 * scale;
    // With tighter hitboxes, the maximum reaching extension matches the character's arm reach.
    final maxReach = 58.0 * scale;
    final reachDist = (dist - sweetSpotOffset).clamp(0.0, maxReach);
    final targetPos = dist > 1.0
        ? charCenter + (diff / dist) * reachDist
        : hoverPos;

    paddlePos = Offset.lerp(hoverPos, targetPos, flightCurve)!;

    // Angle to ball
    final aimAngle = math.atan2(diff.dy, diff.dx);
    // Align elongated blade (-Y in local space) directly towards the ball at contact
    final strikeAngle = aimAngle + math.pi / 2;
    final shortestAngleDiff =
        (strikeAngle - baseAngle + math.pi) % (math.pi * 2) - math.pi;
    final followThrough = (swingProgress - 0.5) * 0.4;
    paddleAngle = baseAngle + shortestAngleDiff * flightCurve + followThrough;
  } else {
    paddlePos = hoverPos;
    paddleAngle = baseAngle + (math.sin(animTimer * 3.5) * 0.08);
  }

  // Draw Kinetic Energy Aura / Glow
  if (flightCurve > 0.05) {
    // Energy Tether / Trail from Hand to Flying Paddle
    final tetherPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.55 * flightCurve)
      ..strokeWidth = 3.0 * scale
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(handPos, paddlePos, tetherPaint);

    final tetherCore = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * flightCurve)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(handPos, paddlePos, tetherCore);

    // Energy Burst / Shockwave around paddle on contact
    final burstPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.45 * flightCurve)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    // Pulse shockwave centered right at the sweet spot
    final sweetSpotWorld = paddlePos + Offset(
      math.sin(paddleAngle) * (19 * scale),
      -math.cos(paddleAngle) * (19 * scale),
    );
    canvas.drawCircle(sweetSpotWorld, 20 * scale * flightCurve, burstPaint);
  } else {
    // Subtle levitation shadow / energy pool underneath floating paddle
    final auraPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: paddlePos.translate(0, 16 * scale),
        width: 16 * scale,
        height: 6 * scale,
      ),
      auraPaint,
    );
  }

  // Draw Paddle Body at paddlePos rotated by paddleAngle
  canvas.translate(paddlePos.dx, paddlePos.dy);
  canvas.rotate(paddleAngle);

  // 1. Paddle Handle / Grip (Elongated pro handle)
  final gripPaint = Paint()
    ..color = const Color(0xFF1E293B) // Dark graphite grip
    ..style = PaintingStyle.fill;
  final gripWrapPaint = Paint()
    ..color = const Color(0xFFF1F5F9) // Premium white perforated overgrip
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3 * scale;
  final gripRect = Rect.fromCenter(
    center: Offset(0, 7.5 * scale),
    width: 3.8 * scale,
    height: 15.0 * scale,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(gripRect, Radius.circular(1.8 * scale)),
    gripPaint,
  );
  // Butt Cap
  final buttCapPaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 15.2 * scale),
        width: 4.8 * scale,
        height: 2.2 * scale,
      ),
      Radius.circular(1.0 * scale),
    ),
    buttCapPaint,
  );
  // Diagonal wrap ridges across the grip
  for (var i = 0; i < 4; i++) {
    final y = 2.0 * scale + i * 3.2 * scale;
    canvas.drawLine(
      Offset(-1.8 * scale, y),
      Offset(1.8 * scale, y + 2.0 * scale),
      gripWrapPaint,
    );
  }

  // Tapered Throat / Neck collar connecting handle to blade
  final throatPaint = Paint()
    ..color = paddleRimColor
    ..style = PaintingStyle.fill;
  final throatPath = Path()
    ..moveTo(-1.9 * scale, 0)
    ..lineTo(-4.5 * scale, -4.5 * scale)
    ..lineTo(4.5 * scale, -4.5 * scale)
    ..lineTo(1.9 * scale, 0)
    ..close();
  canvas.drawPath(throatPath, throatPaint);

  // 2. Elongated Paddle Edge Guard (Outer Rim)
  final rimPaint = Paint()
    ..color = paddleRimColor
    ..style = PaintingStyle.fill;
  final paddleRim = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 15.0 * scale,
      height: 31.0 * scale,
    ),
    Radius.circular(5.5 * scale),
  );
  canvas.drawRRect(paddleRim, rimPaint);

  // 3. Elongated Paddle Face (Raw Carbon / Honeycomb Face)
  final facePaint = Paint()
    ..color = paddleFaceColor
    ..style = PaintingStyle.fill;
  final paddleFace = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 12.6 * scale,
      height: 28.5 * scale,
    ),
    Radius.circular(4.0 * scale),
  );
  canvas.drawRRect(paddleFace, facePaint);

  // Subtle carbon fiber micro-texture stripes
  final texturePaint = Paint()
    ..color = const Color(0x18000000)
    ..strokeWidth = 0.8 * scale;
  for (var i = -4; i <= 4; i++) {
    final y = -19 * scale + i * 3.0 * scale;
    canvas.drawLine(
      Offset(-5.0 * scale, y),
      Offset(5.0 * scale, y),
      texturePaint,
    );
  }

  // 4. Elongated Sweet Spot Core & Target Crosshair Graphic
  final sweetSpotGlow = Paint()
    ..color = sweetSpotColor.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0 * scale;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 7.5 * scale,
      height: 12.0 * scale,
    ),
    sweetSpotGlow,
  );

  final sweetSpotPaint = Paint()
    ..color = sweetSpotColor
    ..style = PaintingStyle.fill;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 4.5 * scale,
      height: 7.5 * scale,
    ),
    sweetSpotPaint,
  );

  final corePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(Offset(0, -19 * scale), 1.4 * scale, corePaint);

  // Dynamic Chevron speed stripes near the top of the elongated paddle
  final chevronPaint = Paint()
    ..color = sweetSpotColor.withValues(alpha: 0.6)
    ..strokeWidth = 1.0 * scale
    ..style = PaintingStyle.stroke;
  final c1 = Path()
    ..moveTo(-3.5 * scale, -29 * scale)
    ..lineTo(0, -31.5 * scale)
    ..lineTo(3.5 * scale, -29 * scale);
  final c2 = Path()
    ..moveTo(-2.5 * scale, -26.5 * scale)
    ..lineTo(0, -28.5 * scale)
    ..lineTo(2.5 * scale, -26.5 * scale);
  canvas.drawPath(c1, chevronPaint);
  canvas.drawPath(c2, chevronPaint);

  canvas.restore();
}

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
    final targetScale = sim.camera
        .project(x: traj.targetX, y: traj.targetY)
        .scale;

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
    final ringRadius =
        (isSmash ? 20.0 : 12.0) * scale +
        progress * (isSmash ? 30.0 : 18.0) * scale;
    final ringPaint = Paint()
      ..color = (isSmash ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF))
          .withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSmash ? 3.5 : 2.0) * (1.0 - progress * 0.5) * scale;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 2. 6 radiating sparks
    final sparkPaint = Paint()
      ..color = (isSmash ? const Color(0xFFFF9800) : const Color(0xFFFFEB3B))
          .withAlpha(alpha)
      ..style = PaintingStyle.fill;

    final sparkDistance =
        10.0 * scale + progress * (isSmash ? 32.0 : 20.0) * scale;
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

class BounceEffectComponent extends Component {
  BounceEffectComponent({required this.center, required this.scale});

  final Offset center;
  final double scale;
  double _lifetime = 0;
  static const double _maxLifetime = 0.28;

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / _maxLifetime).clamp(0.0, 1.0);
    final alpha = ((1 - progress) * 150).round().clamp(0, 255);
    final radius = (8 + progress * 25) * scale;
    final ringPaint = Paint()
      ..color = const Color(0xFFD8F06A).withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.4 - progress) * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2.2,
        height: radius * 0.8,
      ),
      ringPaint,
    );
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
        Offset(
          center.dx + math.cos(angle) * 20 * scale,
          center.dy + math.sin(angle) * 20 * scale,
        ),
        Offset(
          center.dx + math.cos(angle) * (20 * scale + len),
          center.dy + math.sin(angle) * (20 * scale + len),
        ),
        streakPaint,
      );
    }
  }
}
