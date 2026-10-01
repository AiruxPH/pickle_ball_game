import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;

import 'game_debug_config.dart';
import 'match_state.dart';
import 'pickleball_rules.dart';

class CourtPoint {
  const CourtPoint(this.x, this.y);

  final double x;
  final double y;
}
class ProjectedPoint {
  const ProjectedPoint(this.x, this.y, this.scale);

  final double x;
  final double y;
  final double scale;
}

class BallState {
  BallState({
    this.x = 0,
    this.y = -1.05,
    this.z = 0.12,
    this.velocityX = 0.01,
    this.velocityY = 0.02,
    this.velocityZ = 0.02,
    this.hasBounced = false,
  });

  double x;
  double y;
  double z;
  double velocityX;
  double velocityY;
  double velocityZ;
  bool hasBounced;
}

enum CameraMode { action, broadcast, freeRoam, topDown }

enum RallyEnd { playerFault, botFault }

enum SwingResult { hit, missed, kitchenFault, twoBounceFault }

class Camera3D {
  Camera3D() {
    _updateMatrices();
  }

  CameraMode mode = CameraMode.action;
  
  // Free roam controls (controlled by joystick in free roam mode)
  double freeRoamX = 0.0;
  double freeRoamY = 2.0;
  double freeRoamZ = 4.0;
  double freeRoamYaw = math.pi; // looking at -Y
  double freeRoamPitch = -0.5;  // looking slightly down
  
  vmath.Matrix4 _viewProjection = vmath.Matrix4.identity();
  double screenWidth = 400;
  double screenHeight = 800;

  double targetOffsetX = 0.0;
  double targetOffsetY = 0.0;
  double eyeOffsetX = 0.0;
  double eyeOffsetY = 0.0;
  double shakeTrauma = 0.0;

  void updateSize(double width, double height) {
    if (screenWidth == width && screenHeight == height) return;
    screenWidth = width;
    screenHeight = height;
    _updateMatrices();
  }

  void updateDynamics({required double dt, required double ballX, required double playerX, required double playerY, required GameMode gameMode}) {
    double targetEyeX;
    double targetLookX;
    double targetEyeY = 0.0;
    double targetLookY = 0.0;

    if (gameMode == GameMode.freeRoamPractice) {
      // Subtly follow the player more closely in practice mode
      targetEyeX = playerX * 0.4;
      targetLookX = playerX * 0.2;
      targetEyeY = (playerY - 1.8) * 0.4;
      targetLookY = (playerY - 1.8) * 0.2;
    } else {
      // Smoothly track the ball X position slightly for normal match
      targetEyeX = ballX * 0.15;
      targetLookX = ballX * 0.05;
    }

    eyeOffsetX += (targetEyeX - eyeOffsetX) * dt * 3.0;
    targetOffsetX += (targetLookX - targetOffsetX) * dt * 4.0;
    
    eyeOffsetY += (targetEyeY - eyeOffsetY) * dt * 3.0;
    targetOffsetY += (targetLookY - targetOffsetY) * dt * 4.0;

    if (shakeTrauma > 0) {
      shakeTrauma -= dt * 2.5;
      if (shakeTrauma < 0) shakeTrauma = 0;
    }

    _updateMatrices();
  }

  void addShake(double amount) {
    shakeTrauma += amount;
    if (shakeTrauma > 1.0) shakeTrauma = 1.0;
  }

  void _updateMatrices() {
    final aspect = screenWidth / screenHeight;
    final fovY = vmath.radians(60.0);
    final projection = vmath.makePerspectiveMatrix(fovY, aspect, 0.1, 10.0);

    double shakeX = 0;
    double shakeY = 0;
    if (shakeTrauma > 0) {
      final shakeIntensity = shakeTrauma * shakeTrauma;
      shakeX = (math.Random().nextDouble() * 2 - 1) * 0.08 * shakeIntensity;
      shakeY = (math.Random().nextDouble() * 2 - 1) * 0.08 * shakeIntensity;
    }

    vmath.Vector3 eye;
    vmath.Vector3 target;
    vmath.Vector3 up = vmath.Vector3(0.0, 0.0, 1.0);

    switch (mode) {
      case CameraMode.action:
        eye = vmath.Vector3(eyeOffsetX + shakeX, 1.8 + eyeOffsetY + shakeY, 1.0);
        target = vmath.Vector3(targetOffsetX, -0.2 + targetOffsetY, 0.0);
        break;
      case CameraMode.broadcast:
        eye = vmath.Vector3(2.5 + shakeX, 0.0 + shakeY, 1.5);
        target = vmath.Vector3(targetOffsetX, 0.0, 0.0);
        break;
      case CameraMode.freeRoam:
        eye = vmath.Vector3(freeRoamX + shakeX, freeRoamY + shakeY, freeRoamZ);
        
        // Calculate direction vector from yaw and pitch
        final dirX = math.cos(freeRoamPitch) * math.sin(freeRoamYaw);
        final dirY = math.cos(freeRoamPitch) * math.cos(freeRoamYaw);
        final dirZ = math.sin(freeRoamPitch);
        
        target = eye + vmath.Vector3(dirX, dirY, dirZ);
        break;
      case CameraMode.topDown:
        eye = vmath.Vector3(shakeX, shakeY, 3.5);
        target = vmath.Vector3(0.0, 0.0, 0.0);
        up = vmath.Vector3(0.0, -1.0, 0.0); // Looking down Z, Y is up on screen
        break;
    }

    final view = vmath.makeViewMatrix(eye, target, up);
    _viewProjection = projection * view;
  }

  ProjectedPoint project({
    required double x,
    required double y,
    double elevation = 0,
  }) {
    final v = vmath.Vector4(x, y, elevation, 1.0);
    v.applyMatrix4(_viewProjection);

    if (v.w <= 0.001) {
      v.w = 0.001; // Avoid divide by zero, and keep it going outwards
    }

    final ndcX = -v.x / v.w; // Inverted so +X is right, -X is left
    final ndcY = v.y / v.w;
    
    // In NDC, Y is up, X is right.
    // Screen Y is down.
    return ProjectedPoint(ndcX, -ndcY, 1.2 / v.w); 
  }
}

enum MatchPlayPhase { waitingForServe, inRally, deadBall }

/// Tracks the rule-specific stages of a rally independently from the UI flow.
enum RallyPhase {
  waitingForServe,
  serveInFlight,
  receiverMayReturn,
  serverBounceRequired,
  openRally,
  deadBall,
}

enum GameplayEventType {
  playerHit,
  botHit,
  bounce,
  netFault,
  outOfBounds,
  doubleBounce,
  rallyEnd,
}

class GameplayEvent {
  const GameplayEvent(this.type, {this.side, this.isSmash = false});

  final GameplayEventType type;
  final MatchSide? side;
  final bool isSmash;
}

enum GameMode { playerVsBot, botVsBot, freeRoamPractice }
enum MapType { stadium, practiceFacility }

class GameSimulation {
  GameSimulation({
    this.gameMode = GameMode.playerVsBot,
    this.mapType = MapType.stadium,
  }) {
    if (gameMode == GameMode.freeRoamPractice) {
      playPhase = MatchPlayPhase.inRally;
    }
  }

  final GameMode gameMode;
  final MapType mapType;
  static const double courtWidth = PickleballRules.courtWidth;
  static const double courtLength = PickleballRules.courtLength;
  static const double gravity = 0.0012;
  static const double moveSpeed = 0.025;

  final BallState ball = BallState();
  final Camera3D camera = Camera3D();
  final List<GameplayEvent> _events = <GameplayEvent>[];

  List<GameplayEvent> drainEvents() {
    final events = List<GameplayEvent>.unmodifiable(_events);
    _events.clear();
    return events;
  }

  void _emit(GameplayEvent event) => _events.add(event);

  double _telemetryTimer = 0.0;
  double playerX = 0;
  double playerY = 0.75;
  double playerVelocityX = 0;
  double playerVelocityY = 0;
  double playerServeAimAngle = 0.0; // Aim trajectory angle during serve
  
  double bot2ReactionTimer = 0;
  double bot2TargetX = 0;
  double bot2TargetY = 0.75;

  double botX = 0;
  double botY = -0.75;
  
  /// Called when the player dashes — passes (x, y) position.
  void Function(double x, double y)? onPlayerDash;

  void dashPlayer() {
    if (playPhase != MatchPlayPhase.inRally && playPhase != MatchPlayPhase.waitingForServe) return;
    
    if (playerVelocityX.abs() < 0.005 && playerVelocityY.abs() < 0.005) {
      playerVelocityY = -0.15;
    } else {
      playerVelocityX *= 3.5;
      playerVelocityY *= 3.5;
      
      final speed = math.sqrt(playerVelocityX * playerVelocityX + playerVelocityY * playerVelocityY);
      if (speed > 0.25) {
        playerVelocityX = (playerVelocityX / speed) * 0.25;
        playerVelocityY = (playerVelocityY / speed) * 0.25;
      }
    }
    onPlayerDash?.call(playerX, playerY);
  }

  // Asymmetric Player Hitbox (generous forward reach towards net)
  double playerHitRadiusX = 0.42;
  double playerHitFrontY = 0.50; // In front towards net (ball.y < playerY)
  double playerHitBackY = 0.22;  // Behind player (ball.y > playerY)
  double playerHitZMin = 0.0;
  double playerHitZMax = 0.95;
  
  // Asymmetric Bot Hitbox (forward reach towards net: ball.y > botY)
  double botHitRadiusX = 0.42;
  double botHitFrontY = 0.50;
  double botHitBackY = 0.22;
  double botHitZMin = 0.0;
  double botHitZMax = 0.95;
  double get playerHitRadiusY => playerHitFrontY;
  double get botHitRadiusY => botHitFrontY;

  double playerSwingActiveTimer = 0.0;
  void Function(bool isSmash)? onPlayerHit;

  bool canPlayerHitBall() {
    final dx = (ball.x - playerX).abs();
    final dyFront = playerY - ball.y; // > 0 when ball is between player and net
    final inY = dyFront >= -playerHitBackY && dyFront <= playerHitFrontY;
    final inZ = ball.z >= playerHitZMin && ball.z <= playerHitZMax;
    return dx <= playerHitRadiusX && inY && inZ;
  }

  bool canBotHitBall() {
    final dx = (ball.x - botX).abs();
    final dyFront = ball.y - botY; // > 0 when ball is between bot and net
    final inY = dyFront >= -botHitBackY && dyFront <= botHitFrontY;
    final inZ = ball.z >= botHitZMin && ball.z <= botHitZMax;
    return dx <= botHitRadiusX && inY && inZ;
  }

  bool isTwoBounceViolation({required bool forPlayer}) {
    final hitter = forPlayer ? MatchSide.player : MatchSide.bot;
    final receiver =
        servingSide == MatchSide.player ? MatchSide.bot : MatchSide.player;

    switch (rallyPhase) {
      case RallyPhase.serveInFlight:
        return hitter == receiver;
      case RallyPhase.serverBounceRequired:
        return hitter == servingSide;
      case RallyPhase.waitingForServe:
      case RallyPhase.receiverMayReturn:
      case RallyPhase.openRally:
      case RallyPhase.deadBall:
        return false;
    }
  }

  void _recordLegalBounce() {
    switch (rallyPhase) {
      case RallyPhase.serveInFlight:
        rallyPhase = RallyPhase.receiverMayReturn;
        break;
      case RallyPhase.serverBounceRequired:
        rallyPhase = RallyPhase.openRally;
        break;
      case RallyPhase.waitingForServe:
      case RallyPhase.receiverMayReturn:
      case RallyPhase.openRally:
      case RallyPhase.deadBall:
        break;
    }
  }

  void _recordHit({required MatchSide hitter}) {
    rallyLength++;

    if (rallyPhase == RallyPhase.receiverMayReturn && hitter != servingSide) {
      rallyPhase = RallyPhase.serverBounceRequired;
    }
  }

  RallyEnd _endRally(
    RallyEnd result, {
    GameplayEventType? cause,
  }) {
    playPhase = MatchPlayPhase.deadBall;
    rallyPhase = RallyPhase.deadBall;
    final faultSide =
        result == RallyEnd.playerFault ? MatchSide.player : MatchSide.bot;
    if (cause != null) {
      _emit(GameplayEvent(cause, side: faultSide));
    }
    _emit(GameplayEvent(GameplayEventType.rallyEnd, side: faultSide));
    return result;
  }

  void _executePlayerHit({double joystickX = 0.0}) {
    _recordHit(hitter: MatchSide.player);
    lastHitByPlayer = true;
    
    debugPrint('[DATA] ${jsonEncode({'type': 'action', 'action': 'player_swing', 'rallyLength': rallyLength, 'ball': {'x': ball.x, 'y': ball.y, 'z': ball.z}})}');
    
    final isSmash = ball.z > 0.3;
    _emit(GameplayEvent(
      GameplayEventType.playerHit,
      side: MatchSide.player,
      isSmash: isSmash,
    ));
    if (isSmash) {
      ball.velocityY = -0.032;
      ball.velocityZ = 0.010;
    } else {
      ball.velocityY = -0.024;
      ball.velocityZ = 0.022;
    }
    
    // Smart recovery and directional steering:
    // Flight time to bot's half of the court (target Y ~ -0.70)
    const targetCourtY = -0.70;
    final ticks = ((ball.y - targetCourtY).abs() / ball.velocityY.abs()).clamp(20.0, 90.0);
    
    // If recovering a wide ball (|ball.x| > 0.08), bias target towards opposite side / center
    double targetCourtX = 0.0;
    if (ball.x.abs() > 0.08) {
      targetCourtX = -ball.x.sign * 0.12 - ball.x * 0.25;
    }
    
    // If user is steering with joystick, shift shot towards their intended aim
    if (joystickX.abs() > 0.15) {
      targetCourtX = joystickX * (courtWidth * 0.72);
    }
    
    // Clamp safely inside sidelines to eliminate side-out violations
    targetCourtX = targetCourtX.clamp(-courtWidth * 0.78, courtWidth * 0.78);
    
    ball.velocityX = (targetCourtX - ball.x) / ticks;
    ball.hasBounced = false;
  }
  
  bool lastHitByPlayer = false;
  MatchSide servingSide = MatchSide.player;
  MatchPlayPhase playPhase = MatchPlayPhase.inRally;
  RallyPhase rallyPhase = RallyPhase.openRally;
  int currentServerScore = 0;
  
  int rallyLength = 0;
  double get ballSpeed {
    // The simulation court length is normalized to 1.0 for each 22 ft half-court.
    // Velocities are world-units per 25 ms simulation tick.
    final worldUnitsPerTick = math.sqrt(
      ball.velocityX * ball.velocityX +
          ball.velocityY * ball.velocityY +
          ball.velocityZ * ball.velocityZ,
    );
    const feetPerWorldUnit = 22.0;
    const ticksPerSecond = 40.0;
    const mphPerFootPerSecond = 0.681818;
    return worldUnitsPerTick *
        feetPerWorldUnit *
        ticksPerSecond *
        mphPerFootPerSecond;
  }

  void resetRally({MatchSide servingSide = MatchSide.bot, int serverScore = 0}) {
    this.servingSide = servingSide;
    currentServerScore = serverScore;
    lastHitByPlayer = servingSide == MatchSide.player;
    playPhase = MatchPlayPhase.waitingForServe;
    rallyPhase = RallyPhase.waitingForServe;
    rallyLength = 0;
    _events.clear();
    
    ball.velocityZ = 0;
    ball.velocityY = 0;
    ball.velocityX = 0;
    ball.hasBounced = false;
    botServeTimer = 60.0;
    bot2ServeTimer = 60.0;
    playerVelocityX = 0;
    playerVelocityY = 0;
    playerServeAimAngle = 0.0;
    playerSwingActiveTimer = 0.0;
    ball.x = 0;
    ball.y = -1.05;
    ball.z = 0.12;
  }

  double botServeTimer = 0.0;
  double bot2ServeTimer = 0.0;
  double botTargetX = 0.0;
  double botTargetY = -0.75;
  double botReactionTimer = 0.0;
  double botDashTimer = 0.0;
  double botDashCooldown = 0.0; // prevents spam-dashing
  bool botIsDashing = false;    // visual flag

  // Bot Personality (Aggression 0.0 = Defensive, 1.0 = Aggressive)
  double bot1Aggression = 0.2; // Top Bot (Default opponent): Defensive
  double bot2Aggression = 0.8; // Bottom Bot (Player replacement): Aggressive
  double bot2DashCooldown = 0.0;
  bool bot2IsDashing = false;

  double ballMachineTimer = 120.0; // Shoot a ball every 2 seconds roughly

  ({List<({double x, double y, double z})> points, double targetX, double targetY, bool isLegal}) getPlayerServeTrajectory() {
    final isEven = currentServerScore % 2 == 0;
    final baseTargetX = isEven ? -0.227 : 0.227;
    final targetX = (baseTargetX + math.sin(playerServeAimAngle) * 0.22).clamp(-courtWidth * 0.95, courtWidth * 0.95);
    final targetY = -0.66;
    
    final ballStartX = playerX + 0.08;
    final ballStartY = playerY - 0.04;
    const ballStartZ = 0.12;
    
    const double T = 52.0;
    final vx = (targetX - ballStartX) / T;
    final vy = (targetY - ballStartY) / T;
    final vz = (0.5 * gravity * T * T - ballStartZ) / T;
    
    final points = <({double x, double y, double z})>[];
    for (double t = 0; t <= T; t += 2.0) {
      final x = ballStartX + vx * t;
      final y = ballStartY + vy * t;
      final z = math.max(0.0, ballStartZ + vz * t - 0.5 * gravity * t * t);
      points.add((x: x, y: y, z: z));
    }
    
    final isLegal = PickleballRules.isServeInCorrectBox(
      x: targetX,
      y: targetY,
      playerServing: true,
      serveFromLeft: !isEven,
    );
    
    return (points: points, targetX: targetX, targetY: targetY, isLegal: isLegal);
  }

  void triggerServe() {
    if (playPhase != MatchPlayPhase.waitingForServe) return;
    playPhase = MatchPlayPhase.inRally;
    rallyPhase = RallyPhase.serveInFlight;
    
    if (servingSide == MatchSide.player) {
      final traj = getPlayerServeTrajectory();
      const double T = 52.0;
      ball.velocityX = (traj.targetX - (playerX + 0.08)) / T;
      ball.velocityY = (traj.targetY - (playerY - 0.04)) / T;
      ball.velocityZ = (0.5 * gravity * T * T - 0.12) / T;
      lastHitByPlayer = true;
    } else {
      final isEven = currentServerScore % 2 == 0;
      final targetX = isEven ? -0.227 : 0.227;
      final targetY = 0.66;
      const double T = 52.0;
      ball.velocityX = (targetX - (botX + 0.08)) / T;
      ball.velocityY = (targetY - (botY + 0.04)) / T;
      ball.velocityZ = (0.5 * gravity * T * T - 0.12) / T;
      lastHitByPlayer = false;
    }
  }

  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {
    _telemetryTimer += 0.025;
    if (_telemetryTimer >= 0.5) {
      _telemetryTimer = 0.0;
      final telemetryData = {
        'type': 'telemetry',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'bot': {'x': double.parse(botX.toStringAsFixed(3)), 'y': double.parse(botY.toStringAsFixed(3))},
        'botTarget': {'x': double.parse(botTargetX.toStringAsFixed(3)), 'y': double.parse(botTargetY.toStringAsFixed(3))},
        'ball': {
          'x': double.parse(ball.x.toStringAsFixed(3)), 
          'y': double.parse(ball.y.toStringAsFixed(3)), 
          'z': double.parse(ball.z.toStringAsFixed(3)),
          'vx': double.parse(ball.velocityX.toStringAsFixed(4)),
          'vy': double.parse(ball.velocityY.toStringAsFixed(4)),
          'vz': double.parse(ball.velocityZ.toStringAsFixed(4)),
        },
        'rallyLength': rallyLength,
      };
      debugPrint('[DATA] ${jsonEncode(telemetryData)}');
    }
    double jX = joystickX;
    double jY = joystickY;

    if (camera.mode == CameraMode.freeRoam) {
      final forwardX = math.sin(camera.freeRoamYaw);
      final forwardY = math.cos(camera.freeRoamYaw);
      
      final rightX = math.sin(camera.freeRoamYaw - math.pi / 2);
      final rightY = math.cos(camera.freeRoamYaw - math.pi / 2);

      camera.freeRoamX += (-jY * forwardX + jX * rightX) * 0.05;
      camera.freeRoamY += (-jY * forwardY + jX * rightY) * 0.05;
      camera._updateMatrices();
      jX = 0;
      jY = 0;
    }

    if (playPhase == MatchPlayPhase.waitingForServe) {
      final isEven = currentServerScore % 2 == 0;
      final serveX = isEven ? 0.25 : -0.25;
      
      if (servingSide == MatchSide.player) {
        // Player stands completely outside the baseline (Y > courtLength)
        final baselineServeY = courtLength + 0.08;
        
        if (gameMode == GameMode.playerVsBot) {
          if (jX.abs() > 0.05) {
            // Interactive serve aiming and positioning outside the court
            playerServeAimAngle = (playerServeAimAngle + jX * 0.025).clamp(-0.45, 0.45);
            if (isEven) {
              playerX = (playerX + jX * 0.008).clamp(0.06, courtWidth);
            } else {
              playerX = (playerX + jX * 0.008).clamp(-courtWidth, -0.06);
            }
          }
        }
        
        // Position player outside the baseline
        playerY += (baselineServeY - playerY) * 0.15;
        if (playerX == 0) {
          playerX = serveX;
        }
        
        // Bot returns to ready position on its side
        botX += (0 - botX) * 0.1;
        botY += (-0.75 - botY) * 0.1;
        
        // Ball rests on the player/paddle (waist height, not floating in sky)
        ball.x = playerX + 0.08;
        ball.y = playerY - 0.04;
        ball.z = 0.12;

        if (gameMode == GameMode.botVsBot) {
          if (bot2ServeTimer > 0) {
            bot2ServeTimer--;
          } else {
            triggerServe();
          }
        }
      } else {
        // Bot serves outside baseline
        final botBaselineServeY = -courtLength - 0.08;
        botX += (serveX - botX) * 0.1;
        botY += (botBaselineServeY - botY) * 0.1;
        
        // Receiving player can position with joystick while awaiting serve
        if (gameMode == GameMode.playerVsBot) {
          playerVelocityX += (jX * moveSpeed - playerVelocityX) * 0.15;
          playerVelocityY += (jY * moveSpeed - playerVelocityY) * 0.15;
          playerX = (playerX + playerVelocityX).clamp(-courtWidth * 1.25, courtWidth * 1.25);
          playerY = (playerY + playerVelocityY).clamp(0.05, courtLength * 1.35);
        } else {
          playerX += (0 - playerX) * 0.1;
          playerY += (0.75 - playerY) * 0.1;
        }
        
        // Ball on bot paddle at waist height
        ball.x = botX + 0.08;
        ball.y = botY + 0.04;
        ball.z = 0.12;
        
        if (botServeTimer > 0) {
          botServeTimer--;
        } else {
          triggerServe();
        }
      }
      return null;
    }

    if (playPhase == MatchPlayPhase.deadBall) {
      ball.x += ball.velocityX * 0.5;
      ball.y += ball.velocityY * 0.5;
      ball.z += ball.velocityZ;
      if (ball.z > 0) ball.velocityZ -= gravity;
      if (ball.z <= 0) {
        ball.z = 0;
        ball.velocityZ = ball.velocityZ.abs() * 0.5;
        ball.velocityX *= 0.8;
        ball.velocityY *= 0.8;
      }
      camera.updateDynamics(
        dt: 0.025, 
        ballX: ball.x,
        playerX: playerX,
        playerY: playerY,
        gameMode: gameMode,
      );
      
      // Let the player keep moving during dead ball, including outside the baseline!
      if (gameMode == GameMode.playerVsBot) {
        double jX = joystickX;
        double jY = joystickY;
        if (camera.mode == CameraMode.freeRoam) {
          jX = 0;
          jY = 0;
        }
        playerVelocityX += (jX * moveSpeed - playerVelocityX) * 0.15;
        playerVelocityY += (jY * moveSpeed - playerVelocityY) * 0.15;
        playerX = (playerX + playerVelocityX).clamp(-courtWidth * 1.25, courtWidth * 1.25);
        playerY = (playerY + playerVelocityY).clamp(0.05, courtLength * 1.35);
      }
      return null;
    }

    final previousBallY = ball.y;

    // Buffered swing for player: connects cleanly when player swings slightly early
    if (gameMode == GameMode.playerVsBot && playerSwingActiveTimer > 0) {
      playerSwingActiveTimer -= 0.025;
      if (ball.velocityY > 0 && canPlayerHitBall()) {
        if (!GameDebugConfig.bypassKitchenRules) {
          if (PickleballRules.isKitchenVolley(playerY: playerY, ballHasBounced: ball.hasBounced)) {
            playerSwingActiveTimer = 0.0;
            return _endRally(RallyEnd.playerFault);
          }
          if (isTwoBounceViolation(forPlayer: true)) {
            // If ball is descending toward ground on serve/return, wait for bounce instead of premature fault
            if (ball.z > 0.12) {
              return null;
            }
          }
        }
        playerSwingActiveTimer = 0.0;
        final isSmash = ball.z > 0.3;
        _executePlayerHit(joystickX: jX);
        onPlayerHit?.call(isSmash);
      }
    }

    if (gameMode == GameMode.botVsBot) {
      if (bot2ReactionTimer > 0) {
        bot2ReactionTimer--;
      } else {
        bot2ReactionTimer = 10.0;
        if (ball.velocityY > 0) {
          // Ball is coming towards Bot2
          bot2TargetX = ball.x.clamp(-courtWidth * 0.95, courtWidth * 0.95);
          if (bot2Aggression > 0.5 && ball.hasBounced) {
             bot2TargetY = PickleballRules.kitchenDepth; // dash to kitchen
          } else {
             bot2TargetY = ball.y > 0.4 ? ball.y : 0.75;
          }
        } else {
          // Ball is going away
          bot2TargetX = 0;
          bot2TargetY = 0.75;
        }
      }

      final dx = bot2TargetX - playerX;
      final dy = bot2TargetY - playerY;
      final dist = math.sqrt(dx*dx + dy*dy);
      
      if (bot2DashCooldown > 0) bot2DashCooldown--;
      
      // Dash when ball is coming towards this bot and we're far from target
      final ballComingToBot2 = ball.velocityY > 0;
      if (ballComingToBot2 && dist > 0.6 && bot2DashCooldown <= 0) {
        dashPlayer();
        bot2DashCooldown = 80.0;
        bot2IsDashing = true;
      } else {
        bot2IsDashing = false;
      }
      
      if (dist > 0.05) {
        jX = dx / dist;
        jY = dy / dist;
      } else {
        jX = 0;
        jY = 0;
      }

      // Auto-hit
      if (ball.velocityY > 0 &&
          canPlayerHitBall() &&
          (ball.hasBounced || ball.y > courtLength * 0.5)) {
        _recordHit(hitter: MatchSide.player);
        lastHitByPlayer = true;
        
        final isAggressiveHit = math.Random().nextDouble() < bot2Aggression;
        final isError = math.Random().nextDouble() < 0.05; // 5% error rate
        
        ball.velocityY = isAggressiveHit ? -0.030 : -0.024;
        
        if (isError) {
           ball.velocityZ = 0.005; // Hit the net!
           ball.velocityX = (ball.x - playerX) * 0.12 - 0.02; // Or hit out of bounds
        } else {
           ball.velocityZ = isAggressiveHit ? 0.015 : 0.022; // Hard hit is lower arc
           
           const targetCourtY = -0.70;
           final ticks = ((ball.y - targetCourtY).abs() / ball.velocityY.abs()).clamp(20.0, 90.0);
           
           double bot2TargetCourtX = 0.0;
           if (ball.x.abs() > 0.08) {
             bot2TargetCourtX = -ball.x.sign * 0.12 - ball.x * 0.25;
           } else {
             final openSpaceX = botX > 0 ? -0.18 : 0.18;
             bot2TargetCourtX = openSpaceX + (math.Random().nextDouble() - 0.5) * 0.15;
           }
           bot2TargetCourtX = bot2TargetCourtX.clamp(-courtWidth * 0.78, courtWidth * 0.78);
           ball.velocityX = (bot2TargetCourtX - ball.x) / ticks;
        }
        ball.hasBounced = false;
      }
    }

    // Smooth character movement (inertia/momentum)
    final targetVelX = jX * moveSpeed;
    final targetVelY = jY * moveSpeed;
    final friction = gameMode == GameMode.freeRoamPractice ? 0.05 : 0.15;
    playerVelocityX += (targetVelX - playerVelocityX) * friction;
    playerVelocityY += (targetVelY - playerVelocityY) * friction;
    
    if (gameMode == GameMode.freeRoamPractice) {
      playerX = (playerX + playerVelocityX).clamp(-courtWidth * 5.0, courtWidth * 5.0);
      playerY = (playerY + playerVelocityY).clamp(-courtLength * 5.0, courtLength * 5.0);
    } else {
      playerX = (playerX + playerVelocityX).clamp(-courtWidth * 1.25, courtWidth * 1.25);
      playerY = (playerY + playerVelocityY).clamp(0.05, courtLength * 1.35);
    }

    ball.x += ball.velocityX;
    ball.y += ball.velocityY;
    ball.z += ball.velocityZ;
    ball.velocityZ -= gravity;

    if (ball.z <= 0) {
      if (gameMode != GameMode.freeRoamPractice) {
        if (!ball.hasBounced) {
          // A ball cannot bounce on the hitter's own side of the net
          if (lastHitByPlayer && ball.y >= 0) {
            return _endRally(RallyEnd.playerFault);
          }
          if (!lastHitByPlayer && ball.y <= 0) {
            return _endRally(RallyEnd.botFault);
          }

          if (rallyPhase == RallyPhase.serveInFlight) {
            // The first legal bounce of a serve must land in the diagonal
            // service box and beyond the kitchen line.
            final isEven = currentServerScore % 2 == 0;
            final isCorrect = PickleballRules.isServeInCorrectBox(
              x: ball.x,
              y: ball.y,
              playerServing: servingSide == MatchSide.player,
              serveFromLeft: !isEven,
            );
            if (!isCorrect) {
              return _endRally(
                servingSide == MatchSide.player
                    ? RallyEnd.playerFault
                    : RallyEnd.botFault,
              );
            }
          } else if (!PickleballRules.isInsideCourt(ball.x, ball.y)) {
            return _endRally(
              lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault,
              cause: GameplayEventType.outOfBounds,
            );
          }
        } else {
          // Double bounce: fault on the receiving player who let it bounce twice on their side
          return _endRally(
            ball.y > 0 ? RallyEnd.playerFault : RallyEnd.botFault,
            cause: GameplayEventType.doubleBounce,
          );
        }
        _recordLegalBounce();
        _emit(GameplayEvent(
          GameplayEventType.bounce,
          side: ball.y > 0 ? MatchSide.player : MatchSide.bot,
        ));
        ball.z = 0;
        ball.velocityZ = 0.018;
      } else {
        ball.z = 0;
        ball.velocityZ = ball.velocityZ.abs() * 0.6; // damp
        if (ball.velocityZ < 0.005) {
           ball.velocityZ = 0;
           ball.velocityX *= 0.9;
           ball.velocityY *= 0.9;
        }
      }
      ball.hasBounced = true;
    }

    if (gameMode != GameMode.freeRoamPractice) {
      if (previousBallY < 0 && ball.y >= 0 && ball.z < PickleballRules.netHeight) {
        return _endRally(
          RallyEnd.botFault,
          cause: GameplayEventType.netFault,
        );
      }
      if (previousBallY > 0 && ball.y <= 0 && ball.z < PickleballRules.netHeight) {
        return _endRally(
          RallyEnd.playerFault,
          cause: GameplayEventType.netFault,
        );
      }

      // Wide bleacher limits: only terminate when ball completely clears the arena
      if (!ball.hasBounced && (ball.y.abs() > courtLength * 2.2 || ball.x.abs() > courtWidth * 2.5)) {
        return _endRally(
          lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault,
        );
      }
    }

    if (gameMode == GameMode.freeRoamPractice) {
      if (ballMachineTimer > 0) {
        ballMachineTimer--;
      } else {
        // Fire a ball towards the player!
        ball.x = 0;
        ball.y = -courtLength;
        ball.z = 0.5;
        
        final targetX = playerX + (math.Random().nextDouble() - 0.5) * 0.4;
        final targetY = playerY;
        
        final dx = targetX - ball.x;
        final dy = targetY - ball.y;
        final dist = math.sqrt(dx*dx + dy*dy);
        
        ball.velocityX = (dx / dist) * 0.025;
        ball.velocityY = (dy / dist) * 0.025;
        ball.velocityZ = 0.025; // high arc
        ball.hasBounced = false;
        
        lastHitByPlayer = false;
        
        ballMachineTimer = 120.0 + math.Random().nextDouble() * 60; // 3 to 4.5 seconds
      }
    } else if (!GameDebugConfig.freezeAI) {
      if (botReactionTimer > 0) {
        botReactionTimer--;
      } else {
        botReactionTimer = 10.0;
        if (ball.velocityY < 0) {
          // Approaching -> track ball smoothly without random jitter
          botTargetX = ball.x.clamp(-courtWidth * 0.95, courtWidth * 0.95);
          if (bot1Aggression > 0.5 && ball.hasBounced) {
             botTargetY = -PickleballRules.kitchenDepth; // stay just behind kitchen
          } else {
             botTargetY = ball.y < -0.4 ? ball.y : -0.75;
          }
        } else {
          // Returning -> go to ready center
          botTargetX = 0;
          botTargetY = -0.75;
        }
      }
      
      final dx = botTargetX - botX;
      final dy = botTargetY - botY;
      final dist = math.sqrt(dx*dx + dy*dy);
      
      // Tick cooldown
      if (botDashCooldown > 0) botDashCooldown--;
      if (botDashTimer > 0) {
        botDashTimer--;
        botIsDashing = true;
      } else {
        botIsDashing = false;
      }

      // Trigger dash only when: ball is coming, we are far, and cooldown is expired
      final ballComingToBot = ball.velocityY < 0;
      if (ballComingToBot && dist > 0.6 && botDashCooldown <= 0 && botDashTimer <= 0) {
        debugPrint('[DATA] ${jsonEncode({'type': 'action', 'action': 'dash', 'bot': {'x': botX, 'y': botY}, 'target': {'x': botTargetX, 'y': botTargetY}, 'distance': dist})}');
        botDashTimer = 12.0;           // dash lasts 12 ticks
        botDashCooldown = 80.0;        // cannot dash again for 2 seconds (80 * 25ms)
      }

      final double speed = botIsDashing ? 0.05 : 0.015;

      // Move smoothly to target without overshooting/vibrating
      if (dist > 0.02) {
        final step = math.min(speed, dist);
        botX += (dx / dist) * step;
        botY += (dy / dist) * step;
      }
      botX = botX.clamp(-courtWidth * 1.25, courtWidth * 1.25);
      botY = botY.clamp(-courtLength * 1.35, -0.05);
    }

    if (ball.velocityY < 0 && canBotHitBall()) {
      if (isTwoBounceViolation(forPlayer: false)) {
        // Wait for bounce
      } else {
        _recordHit(hitter: MatchSide.bot);
        lastHitByPlayer = false;
        
        final isAggressiveHit = math.Random().nextDouble() < bot1Aggression;
        final isError = math.Random().nextDouble() < 0.05; // 5% error rate
        _emit(GameplayEvent(
          GameplayEventType.botHit,
          side: MatchSide.bot,
          isSmash: isAggressiveHit,
        ));
        
        debugPrint('[DATA] ${jsonEncode({'type': 'action', 'action': 'swing', 'aggressive': isAggressiveHit, 'error': isError, 'rallyLength': rallyLength, 'ball': {'x': ball.x, 'y': ball.y, 'z': ball.z}})}');
        
        ball.velocityY = isAggressiveHit ? 0.030 : 0.024;
        
        if (isError) {
           ball.velocityZ = 0.005; // Hit the net!
           ball.velocityX = (ball.x - botX) * 0.12 + 0.02; // Or hit out of bounds
        } else {
           ball.velocityZ = isAggressiveHit ? 0.015 : 0.022; // Hard hit is lower arc
           
           // Smart recovery and court targeting: target player's court (Y ~ 0.70)
           const targetCourtY = 0.70;
           final ticks = ((targetCourtY - ball.y).abs() / ball.velocityY.abs()).clamp(20.0, 90.0);
           
           // Aim into court, with recovery angle if hit from the side
           double botTargetCourtX = 0.0;
           if (ball.x.abs() > 0.08) {
             // Angle back across/center to cleanly recover side balls
             botTargetCourtX = -ball.x.sign * 0.12 - ball.x * 0.25;
           } else {
             // Slight aim variation towards open court
             final openSpaceX = playerX > 0 ? -0.18 : 0.18;
             botTargetCourtX = openSpaceX + (math.Random().nextDouble() - 0.5) * 0.15;
           }
           
           // Clamp safely inside sidelines so bot doesn't commit side-out violations
           botTargetCourtX = botTargetCourtX.clamp(-courtWidth * 0.78, courtWidth * 0.78);
           ball.velocityX = (botTargetCourtX - ball.x) / ticks;
        }
        ball.hasBounced = false;
      }
    }

    camera.updateDynamics(
      dt: 0.025, 
      ballX: ball.x,
      playerX: playerX,
      playerY: playerY,
      gameMode: gameMode,
    );
    return null;
  }

  SwingResult swing({double joystickX = 0.0}) {
    if (playPhase == MatchPlayPhase.waitingForServe) {
      if (servingSide == MatchSide.player) {
        triggerServe();
        return SwingResult.hit;
      }
      return SwingResult.missed;
    }
    
    // Check hit radius first
    if (!canPlayerHitBall()) {
      // Buffer the swing so hitting slightly early still connects as the ball enters reach
      playerSwingActiveTimer = 0.20;
      return SwingResult.missed;
    }

    if (gameMode != GameMode.freeRoamPractice && !GameDebugConfig.bypassKitchenRules) {
      if (PickleballRules.isKitchenVolley(
        playerY: playerY,
        ballHasBounced: ball.hasBounced,
      )) {
        return SwingResult.kitchenFault;
      }
      if (isTwoBounceViolation(forPlayer: true)) {
        if (ball.z > 0.12) {
          return SwingResult.twoBounceFault;
        }
      }
    }

    playerSwingActiveTimer = 0.0;
    final isSmash = ball.z > 0.3;
    _executePlayerHit(joystickX: joystickX);
    onPlayerHit?.call(isSmash);
    return SwingResult.hit;
  }

  double ballScale() => 1 + ball.z * 0.45;

  double ballShadowScale() => math.max(0.35, 1 - ball.z * 0.5);
}
