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

enum RallyEnd { playerFault, botFault }

enum SwingResult { hit, missed, kitchenFault }

class Camera3D {
  Camera3D() {
    _updateMatrices();
  }

  vmath.Matrix4 _viewProjection = vmath.Matrix4.identity();
  double screenWidth = 400;
  double screenHeight = 800;

  double targetOffsetX = 0.0;
  double eyeOffsetX = 0.0;
  double shakeTrauma = 0.0;

  void updateSize(double width, double height) {
    if (screenWidth == width && screenHeight == height) return;
    screenWidth = width;
    screenHeight = height;
    _updateMatrices();
  }

  void updateDynamics({required double dt, required double ballX}) {
    // Smoothly track the ball X position slightly
    final targetEyeX = ballX * 0.15;
    final targetLookX = ballX * 0.05;

    eyeOffsetX += (targetEyeX - eyeOffsetX) * dt * 3.0;
    targetOffsetX += (targetLookX - targetOffsetX) * dt * 4.0;

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

    final eye = vmath.Vector3(eyeOffsetX + shakeX, 1.8 + shakeY, 1.0);
    final target = vmath.Vector3(targetOffsetX, -0.2, 0.0);
    final up = vmath.Vector3(0.0, 0.0, 1.0);

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

class GameSimulation {
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
  double botX = 0;
  double botY = -0.75;

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

  void resetRally({MatchSide servingSide = MatchSide.bot, int serverScore = 0}) {
    this.servingSide = servingSide;
    this.currentServerScore = serverScore;
    lastHitByPlayer = servingSide == MatchSide.player;
    playPhase = MatchPlayPhase.waitingForServe;
    
    ball.velocityZ = 0;
    ball.velocityY = 0;
    ball.velocityX = 0;
    ball.hasBounced = false;
    botServeTimer = 60.0;
    playerVelocityX = 0;
    playerVelocityY = 0;
  }

  double botServeTimer = 0.0;
  double botTargetX = 0.0;
  double botReactionTimer = 0.0;

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
      camera.updateDynamics(dt: 0.025, ballX: ball.x);
      return null;
    }

    final previousBallY = ball.y;
    
    // Smooth character movement (inertia/momentum)
    final targetVelX = joystickX * moveSpeed;
    final targetVelY = joystickY * moveSpeed;
    playerVelocityX += (targetVelX - playerVelocityX) * 0.15;
    playerVelocityY += (targetVelY - playerVelocityY) * 0.15;
    
    playerX = (playerX + playerVelocityX).clamp(-courtWidth, courtWidth);
    playerY = (playerY + playerVelocityY).clamp(0.05, courtLength);

    ball.x += ball.velocityX;
    ball.y += ball.velocityY;
    ball.z += ball.velocityZ;
    ball.velocityZ -= gravity;

    if (ball.z <= 0) {
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
      ball.hasBounced = true;
    }

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

    if (!GameDebugConfig.freezeAI) {
      if (botReactionTimer > 0) {
        botReactionTimer--;
      } else {
        botReactionTimer = 15.0;
        if (ball.velocityY < 0) {
          // Approaching -> track ball with human error
          botTargetX = ball.x + (math.Random().nextDouble() - 0.5) * 0.3;
        } else {
          // Returning -> go to center
          botTargetX = 0;
        }
      }
      
      final dist = botTargetX - botX;
      if (dist.abs() > 0.02) {
        botX += dist.sign * 0.015;
      }
      botX = botX.clamp(-courtWidth, courtWidth);
    }

    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() <= botHitRadiusY &&
        (ball.x - botX).abs() <= botHitRadiusX &&
        ball.z >= botHitZMin &&
        ball.z <= botHitZMax &&
        ball.hasBounced) {
      lastHitByPlayer = false;
      ball.velocityY = 0.024;
      ball.velocityZ = 0.022; // higher arc to clear the net!
      ball.velocityX = (ball.x - botX) * 0.12;
      ball.hasBounced = false;
    }

    camera.updateDynamics(dt: 0.025, ballX: ball.x);
    return null;
  }

  SwingResult swing() {
    if (playPhase == MatchPlayPhase.waitingForServe) {
      triggerServe();
      return SwingResult.hit;
    }
    if (!GameDebugConfig.bypassKitchenRules && PickleballRules.isKitchenVolley(
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