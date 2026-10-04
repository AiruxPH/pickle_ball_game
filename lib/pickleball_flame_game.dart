import 'dart:math' as math;
import 'dart:ui' show Offset, Image;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import 'components/animated_vfx_component.dart';
import 'components/ball_visual_component.dart';
import 'components/bot_visual_component.dart';
import 'components/bounce_effect_component.dart';
import 'components/court_visual_component.dart';
import 'components/dash_effect_component.dart';
import 'components/hit_effect_component.dart';
import 'components/player_visual_component.dart';
import 'game_debug_config.dart';
import 'game_simulation.dart';
import 'match_state.dart';
import 'models/paddle_item.dart';
import 'settings_manager.dart';

export 'components/animated_vfx_component.dart';
export 'components/ball_visual_component.dart';
export 'components/bot_visual_component.dart';
export 'components/bounce_effect_component.dart';
export 'components/court_visual_component.dart';
export 'components/dash_effect_component.dart';
export 'components/draw_kinetic_paddle.dart';
export 'components/hit_effect_component.dart';
export 'components/player_visual_component.dart';

Offset normalizeDirectionalInput(double x, double y) {
  var normalizedX = x.clamp(-1.0, 1.0).toDouble();
  var normalizedY = y.clamp(-1.0, 1.0).toDouble();
  final magnitude = math.sqrt(
    normalizedX * normalizedX + normalizedY * normalizedY,
  );
  if (magnitude > 1.0) {
    normalizedX /= magnitude;
    normalizedY /= magnitude;
  }
  return Offset(normalizedX, normalizedY);
}

/// Flame game orchestrator managing the simulation tick, sprite sheets,
/// camera sizing, inputs, visual components, and VFX spawns.
class PickleballFlameGame extends FlameGame {
  PickleballFlameGame({GameSimulation? simulation, this.onRallyEnd})
      : simulation = simulation ?? GameSimulation() {
    randomizeBotPaddles();
  }

  static const double fixedStep = 0.025;

  late PaddleItem topBotPaddle;
  late PaddleItem bottomBotPaddle;

  /// Randomly equips a paddle from the catalog for each bot.
  void randomizeBotPaddles([math.Random? random]) {
    topBotPaddle = PaddleCatalog.getRandomPaddle(random);
    var bottom = PaddleCatalog.getRandomPaddle(random);
    if (PaddleCatalog.allPaddles.length > 1) {
      while (bottom.id == topBotPaddle.id) {
        bottom = PaddleCatalog.getRandomPaddle(random);
      }
    }
    bottomBotPaddle = bottom;
  }

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
  double botSwingTimer = 0;
  double playerBotSwingTimer = 0;

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

  void spawnHitEffect({required bool isSmash, PaddleItem? paddle}) {
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

    final equipped = paddle ?? PaddleCatalog.getById(SettingsManager().equippedPaddleId);
    if (equipped.vfxAsset != null) {
      add(
        AnimatedVfxComponent(
          center: center,
          scale: point.scale,
          paddle: equipped,
          game: this,
        ),
      );
    }

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

    final normalizedInput = normalizeDirectionalInput(
      currentInputX,
      currentInputY,
    );
    effectiveInputX = normalizedInput.dx;
    effectiveInputY = normalizedInput.dy;

    while (_timeAccumulator >= fixedStep) {
      final rallyEnd = simulation.update(
        joystickX: effectiveInputX,
        joystickY: effectiveInputY,
      );
      _timeAccumulator -= fixedStep;

      for (final event in simulation.drainEvents()) {
        switch (event.type) {
          case GameplayEventType.botHit:
            final botPaddle = (event.side == MatchSide.player)
                ? bottomBotPaddle
                : topBotPaddle;
            if (event.side == MatchSide.player) {
              isSwinging = true;
              playerBotSwingTimer = 0.15;
            } else {
              isBotSwinging = true;
              botSwingTimer = 0.15;
            }
            spawnHitEffect(
              isSmash: event.isSmash,
              paddle: botPaddle,
            );
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
}
