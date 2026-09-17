import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;

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

  void updateSize(double width, double height) {
    if (screenWidth == width && screenHeight == height) return;
    screenWidth = width;
    screenHeight = height;
    _updateMatrices();
  }

  void _updateMatrices() {
    final aspect = screenWidth / screenHeight;
    final fovY = vmath.radians(60.0);
    final projection = vmath.makePerspectiveMatrix(fovY, aspect, 0.1, 10.0);

    // Position camera behind the player (y = 1.6), at height z = 1.0
    // Look slightly past the net (y = -0.2)
    final eye = vmath.Vector3(0.0, 1.8, 1.0);
    final target = vmath.Vector3(0.0, -0.2, 0.0);
    final up = vmath.Vector3(0.0, 0.0, 1.0); // Z is up

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

    if (v.w <= 0.0) {
      return const ProjectedPoint(0, 0, 0);
    }

    final ndcX = v.x / v.w;
    final ndcY = v.y / v.w;
    
    // In NDC, Y is up, X is right.
    // Screen Y is down.
    return ProjectedPoint(ndcX, -ndcY, 1.2 / v.w); 
  }
}

class GameSimulation {
  static const double courtWidth = PickleballRules.courtWidth;
  static const double courtLength = PickleballRules.courtLength;
  static const double gravity = 0.0012;
  static const double moveSpeed = 0.025;

  final BallState ball = BallState();
  final Camera3D camera = Camera3D();

  double playerX = 0;
  double playerY = 0.75;
  double botX = 0;
  double botY = -0.75;
  bool lastHitByPlayer = false;
  MatchSide servingSide = MatchSide.bot;
  RallyPhase rallyPhase = RallyPhase.botServe;

  void resetRally({MatchSide servingSide = MatchSide.bot}) {
  this.servingSide = servingSide;
  lastHitByPlayer = servingSide == MatchSide.player;

  if (servingSide == MatchSide.bot) {
    rallyPhase = RallyPhase.botServe;

    ball
      ..x = 0
      ..y = -0.75
      ..z = 0.4
      ..velocityX = 0.008
      ..velocityY = 0.022
      ..velocityZ = 0.015
      ..hasBounced = false;
  } else {
    rallyPhase = RallyPhase.playerServe;

    ball
      ..x = 0
      ..y = 0.75
      ..z = 0.4
      ..velocityX = -0.008
      ..velocityY = -0.022
      ..velocityZ = 0.015
      ..hasBounced = false;
  }
}

  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {
    final previousBallY = ball.y;
    playerX = (playerX + joystickX * moveSpeed).clamp(-courtWidth, courtWidth);
    playerY = (playerY + joystickY * moveSpeed).clamp(0.05, courtLength);

    ball.x += ball.velocityX;
    ball.y += ball.velocityY;
    ball.z += ball.velocityZ;
    ball.velocityZ -= gravity;

    if (ball.z <= 0) {
      if (!ball.hasBounced) {
        if (!PickleballRules.isInsideCourt(ball.x, ball.y)) {
          return lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault;
        }
      } else {
        return lastHitByPlayer ? RallyEnd.botFault : RallyEnd.playerFault;
      }
      ball.z = 0;
      ball.velocityZ = 0.018;
      ball.hasBounced = true;
    }

    if (previousBallY < 0 && ball.y >= 0 && ball.z < PickleballRules.netHeight) {
      return RallyEnd.botFault;
    }
    if (previousBallY > 0 && ball.y <= 0 && ball.z < PickleballRules.netHeight) {
      return RallyEnd.playerFault;
    }

    if (!ball.hasBounced && (ball.y.abs() > courtLength * 1.5 || ball.x.abs() > courtWidth * 1.5)) {
      return lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault;
    }

    if (ball.velocityY < 0) {
      final targetX = ball.x;
      if ((botX - targetX).abs() > 0.08) {
        botX += botX < targetX ? 0.012 : -0.012; // slightly faster bot
      }
    }
    botX = botX.clamp(-courtWidth, courtWidth);

    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() < 0.20 &&
        (ball.x - botX).abs() < 0.25 &&
        ball.z < 0.4 &&
        ball.hasBounced) {
      lastHitByPlayer = false;
      ball.velocityY = 0.024;
      ball.velocityZ = 0.022; // higher arc to clear the net!
      ball.velocityX = (ball.x - botX) * 0.12;
      ball.hasBounced = false;
    }

    return null;
  }

  SwingResult swing() {
    final distance = (ball.x - playerX).abs() + (ball.y - playerY).abs();
    if (PickleballRules.isKitchenVolley(
      playerY: playerY,
      ballHasBounced: ball.hasBounced,
    )) {
      return SwingResult.kitchenFault;
    }
    if (distance >= 0.35 || ball.z <= 0.05 || ball.z >= 0.6) {
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