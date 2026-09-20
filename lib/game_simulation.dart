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
    this.y = 0,
    this.z = 0.4,
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

enum SwingResult { hit, missed, kitchenFault }

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

  double playerX = 0;
  double playerY = 0.75;
  double playerVelocityX = 0;
  double playerVelocityY = 0;
  
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

  // Adjustable Hitboxes
  double playerHitRadiusX = 0.2;
  double playerHitRadiusY = 0.2;
  double playerHitZMin = 0.05;
  double playerHitZMax = 0.6;
  
  double botHitRadiusX = 0.2;
  double botHitRadiusY = 0.2;
  double botHitZMin = 0.0;
  double botHitZMax = 0.4;
  
  bool lastHitByPlayer = false;
  MatchSide servingSide = MatchSide.bot;
  MatchPlayPhase playPhase = MatchPlayPhase.deadBall;
  int currentServerScore = 0;
  
  int rallyLength = 0;
  double get ballSpeed {
    return math.sqrt(ball.velocityX * ball.velocityX + ball.velocityY * ball.velocityY + ball.velocityZ * ball.velocityZ) * 1000;
  }

  void resetRally({MatchSide servingSide = MatchSide.bot, int serverScore = 0}) {
    this.servingSide = servingSide;
    currentServerScore = serverScore;
    lastHitByPlayer = servingSide == MatchSide.player;
    playPhase = MatchPlayPhase.waitingForServe;
    rallyLength = 0;
    
    ball.velocityZ = 0;
    ball.velocityY = 0;
    ball.velocityX = 0;
    ball.hasBounced = false;
    botServeTimer = 60.0;
    bot2ServeTimer = 60.0;
    playerVelocityX = 0;
    playerVelocityY = 0;
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

  void triggerServe() {
    if (playPhase != MatchPlayPhase.waitingForServe) return;
    playPhase = MatchPlayPhase.inRally;
    
    if (servingSide == MatchSide.player) {
      ball.velocityX = (currentServerScore % 2 == 0) ? -0.015 : 0.015; // Aim cross court
      ball.velocityY = -0.024;
      ball.velocityZ = 0.016;
      lastHitByPlayer = true;
    } else {
      ball.velocityX = (currentServerScore % 2 == 0) ? -0.015 : 0.015;
      ball.velocityY = 0.024;
      ball.velocityZ = 0.016;
      lastHitByPlayer = false;
    }
  }

  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {
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
      final serveX = isEven ? 0.4 : -0.4;
      
      if (servingSide == MatchSide.player) {
        // Smoothly walk to serve position
        playerX += (serveX - playerX) * 0.1;
        playerY += (0.85 - playerY) * 0.1;
        botX += (0 - botX) * 0.1;
        botY += (-0.75 - botY) * 0.1; // Bot returns to center
        
        ball.x = playerX;
        ball.y = playerY - 0.1;
        ball.z = 0.4;

        if (gameMode == GameMode.botVsBot) {
          if (bot2ServeTimer > 0) {
            bot2ServeTimer--;
          } else {
            triggerServe();
          }
        }
      } else {
        botX += (serveX - botX) * 0.1;
        botY += (-0.85 - botY) * 0.1; // Behind baseline
        playerX += (0 - playerX) * 0.1;
        playerY += (0.75 - playerY) * 0.1; // Player returns to center
        
        ball.x = botX;
        ball.y = botY + 0.1;
        ball.z = 0.4;
        
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
      
      // Let the player keep moving during dead ball!
      if (gameMode == GameMode.playerVsBot) {
        double jX = joystickX;
        double jY = joystickY;
        if (camera.mode == CameraMode.freeRoam) {
          jX = 0;
          jY = 0;
        }
        playerVelocityX += (jX * moveSpeed - playerVelocityX) * 0.15;
        playerVelocityY += (jY * moveSpeed - playerVelocityY) * 0.15;
        playerX = (playerX + playerVelocityX).clamp(-courtWidth, courtWidth);
        playerY = (playerY + playerVelocityY).clamp(0.05, courtLength);
      }
      return null;
    }

    final previousBallY = ball.y;

    if (gameMode == GameMode.botVsBot) {
      if (bot2ReactionTimer > 0) {
        bot2ReactionTimer--;
      } else {
        bot2ReactionTimer = 15.0;
        if (ball.velocityY > 0) {
          // Ball is coming towards Bot2
          bot2TargetX = ball.x + (math.Random().nextDouble() - 0.5) * 0.3;
          if (bot2Aggression > 0.5 && ball.hasBounced) {
             bot2TargetY = 0.3; // dash to kitchen
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
      
      if (dist > 0.1) {
        jX = dx / dist;
        jY = dy / dist;
      } else {
        jX = 0;
        jY = 0;
      }

      // Auto-hit
      if (ball.velocityY > 0 &&
          (ball.y - playerY).abs() <= playerHitRadiusY &&
          (ball.x - playerX).abs() <= playerHitRadiusX &&
          ball.z >= playerHitZMin &&
          ball.z <= playerHitZMax &&
          (ball.hasBounced || ball.y > courtLength * 0.5)) {
        rallyLength++;
        lastHitByPlayer = true;
        
        final isAggressiveHit = math.Random().nextDouble() < bot2Aggression;
        final isError = math.Random().nextDouble() < 0.05; // 5% error rate
        
        ball.velocityY = isAggressiveHit ? -0.03 : -0.024;
        
        if (isError) {
           ball.velocityZ = 0.005; // Hit the net!
           ball.velocityX = (ball.x - playerX) * 0.12 - 0.02; // Or hit out of bounds
        } else {
           ball.velocityZ = isAggressiveHit ? 0.015 : 0.022; // Hard hit is lower arc
           ball.velocityX = (ball.x - playerX) * 0.12;
        }
        ball.hasBounced = false;
      }
    }

    // Smooth character movement (inertia/momentum)
    final targetVelX = jX * moveSpeed;
    final targetVelY = jY * moveSpeed;
    playerVelocityX += (targetVelX - playerVelocityX) * 0.15;
    playerVelocityY += (targetVelY - playerVelocityY) * 0.15;
    
    if (gameMode == GameMode.freeRoamPractice) {
      playerX = (playerX + playerVelocityX).clamp(-courtWidth * 5.0, courtWidth * 5.0);
      playerY = (playerY + playerVelocityY).clamp(-courtLength * 5.0, courtLength * 5.0);
    } else {
      playerX = (playerX + playerVelocityX).clamp(-courtWidth, courtWidth);
      playerY = (playerY + playerVelocityY).clamp(0.05, courtLength);
    }

    ball.x += ball.velocityX;
    ball.y += ball.velocityY;
    ball.z += ball.velocityZ;
    ball.velocityZ -= gravity;

    if (ball.z <= 0) {
      if (gameMode != GameMode.freeRoamPractice) {
        if (!ball.hasBounced) {
          if (!PickleballRules.isInsideCourt(ball.x, ball.y)) {
            playPhase = MatchPlayPhase.deadBall;
            return lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault;
          }
        } else {
          playPhase = MatchPlayPhase.deadBall;
          return lastHitByPlayer ? RallyEnd.botFault : RallyEnd.playerFault;
        }
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
        playPhase = MatchPlayPhase.deadBall;
        return RallyEnd.botFault;
      }
      if (previousBallY > 0 && ball.y <= 0 && ball.z < PickleballRules.netHeight) {
        playPhase = MatchPlayPhase.deadBall;
        return RallyEnd.playerFault;
      }

      if (!ball.hasBounced && (ball.y.abs() > courtLength * 1.5 || ball.x.abs() > courtWidth * 1.5)) {
        playPhase = MatchPlayPhase.deadBall;
        return lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault;
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
        botReactionTimer = 15.0;
        if (ball.velocityY < 0) {
          // Approaching -> track ball with human error
          botTargetX = ball.x + (math.Random().nextDouble() - 0.5) * 0.3;
          if (bot1Aggression > 0.5 && ball.hasBounced) {
             botTargetY = -0.3; // dash to kitchen
          } else {
             botTargetY = ball.y < -0.4 ? ball.y : -0.75;
          }
        } else {
          // Returning -> go to center
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
        botDashTimer = 12.0;           // dash lasts 12 ticks
        botDashCooldown = 80.0;        // cannot dash again for 2 seconds (80 * 25ms)
      }

      final double speed = botIsDashing ? 0.05 : 0.015;

      if (dist > 0.05) {
        botX += (dx / dist) * speed;
        botY += (dy / dist) * speed;
      }
      botX = botX.clamp(-courtWidth, courtWidth);
      botY = botY.clamp(-courtLength, -0.05);
    }

    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() <= botHitRadiusY &&
        (ball.x - botX).abs() <= botHitRadiusX &&
        ball.z >= botHitZMin &&
        ball.z <= botHitZMax &&
        ball.hasBounced) {
      rallyLength++;
      lastHitByPlayer = false;
      
      final isAggressiveHit = math.Random().nextDouble() < bot1Aggression;
      final isError = math.Random().nextDouble() < 0.05; // 5% error rate
      
      ball.velocityY = isAggressiveHit ? 0.03 : 0.024;
      
      if (isError) {
         ball.velocityZ = 0.005; // Hit the net!
         ball.velocityX = (ball.x - botX) * 0.12 + 0.02; // Or hit out of bounds
      } else {
         ball.velocityZ = isAggressiveHit ? 0.015 : 0.022; // Hard hit is lower arc
         ball.velocityX = (ball.x - botX) * 0.12;
      }
      ball.hasBounced = false;
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

  SwingResult swing() {
    if (playPhase == MatchPlayPhase.waitingForServe) {
      if (servingSide == MatchSide.player) {
        triggerServe();
        return SwingResult.hit;
      }
      return SwingResult.missed;
    }
    if (gameMode != GameMode.freeRoamPractice && !GameDebugConfig.bypassKitchenRules && PickleballRules.isKitchenVolley(
      playerY: playerY,
      ballHasBounced: ball.hasBounced,
    )) {
      return SwingResult.kitchenFault;
    }
    if ((ball.x - playerX).abs() > playerHitRadiusX || 
        (ball.y - playerY).abs() > playerHitRadiusY || 
        ball.z < playerHitZMin || 
        ball.z > playerHitZMax) {
      return SwingResult.missed;
    }

    rallyLength++;
    lastHitByPlayer = true;
    if (ball.z > 0.3) {
      ball.velocityY = -0.032;
      ball.velocityZ = 0.01;
    } else {
      ball.velocityY = -0.022;
      ball.velocityZ = 0.022;
    }
    ball.velocityX = (ball.x - playerX) * 0.12;
    ball.hasBounced = false;
    return SwingResult.hit;
  }

  double ballScale() => 1 + ball.z * 0.45;

  double ballShadowScale() => math.max(0.35, 1 - ball.z * 0.5);
}