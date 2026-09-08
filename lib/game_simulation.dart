import 'dart:math' as math;

class CourtPoint {
  const CourtPoint(this.x, this.y);

  final double x;
  final double y;
}

class ProjectedPoint {
  const ProjectedPoint(this.x, this.y);

  final double x;
  final double y;
}

class BallState {
  BallState({
    this.x = 0,
    this.y = 0,
    this.z = 0.4,
    this.velocityX = 0.01,
    this.velocityY = 0.02,
    this.velocityZ = 0.02,
  });

  double x;
  double y;
  double z;
  double velocityX;
  double velocityY;
  double velocityZ;
}

class CourtProjection {
  const CourtProjection({
    required this.courtWidth,
    required this.courtLength,
  });

  final double courtWidth;
  final double courtLength;

  ProjectedPoint project({
    required double x,
    required double y,
    double elevation = 0,
  }) {
    final depth = depthScaleAt(y);
    return ProjectedPoint(
      (x / courtWidth) * depth,
      (y / courtLength) - elevation * 0.22,
    );
  }

  double depthScaleAt(double y) {
    final normalizedDepth = ((y + courtLength) / (courtLength * 2)).clamp(0, 1);
    return 0.84 + normalizedDepth * 0.16;
  }
}

class GameSimulation {
  static const double courtWidth = 1.4;
  static const double courtLength = 1.3;
  static const double gravity = 0.0012;
  static const double moveSpeed = 0.025;

  final BallState ball = BallState();
  final CourtProjection projection = const CourtProjection(
    courtWidth: courtWidth,
    courtLength: courtLength,
  );

  double playerX = 0;
  double playerY = 0.75;
  double botX = 0;
  double botY = -0.75;
  bool lastHitByPlayer = false;

  void resetRally() {
    ball
      ..x = 0
      ..y = -0.6
      ..z = 0.4
      ..velocityX = 0.008
      ..velocityY = 0.022
      ..velocityZ = 0.015;
    lastHitByPlayer = false;
  }

  void update({double joystickX = 0, double joystickY = 0}) {
    playerX = (playerX + joystickX * moveSpeed).clamp(-courtWidth, courtWidth);
    playerY = (playerY + joystickY * moveSpeed).clamp(0.05, courtLength);

    ball.x += ball.velocityX;
    ball.y += ball.velocityY;
    ball.z += ball.velocityZ;
    ball.velocityZ -= gravity;

    if (ball.z <= 0) {
      ball.z = 0;
      ball.velocityZ = 0.018;
    }

    if (ball.velocityY < 0) {
      final targetX = ball.x;
      if ((botX - targetX).abs() > 0.08) {
        botX += botX < targetX ? 0.009 : -0.009;
      }
    }
    botX = botX.clamp(-courtWidth, courtWidth);

    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() < 0.18 &&
        (ball.x - botX).abs() < 0.22 &&
        ball.z < 0.4) {
      lastHitByPlayer = false;
      ball.velocityY = 0.020;
      ball.velocityZ = 0.018;
      ball.velocityX = (ball.x - botX) * 0.08;
    }
  }

  bool swing() {
    final distance = (ball.x - playerX).abs() + (ball.y - playerY).abs();
    if (distance >= 0.35 || ball.z <= 0.05 || ball.z >= 0.6) {
      return false;
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
    return true;
  }

  double ballScale() => 1 + ball.z * 0.45;

  double ballShadowScale() => math.max(0.35, 1 - ball.z * 0.5);
}