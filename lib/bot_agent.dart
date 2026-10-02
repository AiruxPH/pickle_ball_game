import 'dart:math' as math;

import 'pickleball_rules.dart';

enum BotCourtSide { top, bottom }

enum BotShotType { safeReturn, drive, smash }

enum BotDifficulty { easy, normal, hard }

class BotDifficultySettings {
  const BotDifficultySettings({
    required this.reactionTicks,
    required this.moveSpeed,
    required this.dashSpeed,
    required this.aggression,
    required this.errorRate,
    required this.aimError,
  });

  final double reactionTicks;
  final double moveSpeed;
  final double dashSpeed;
  final double aggression;
  final double errorRate;
  final double aimError;
}

class BotPersonality {
  const BotPersonality({
    required this.name,
    this.aggressionAdjustment = 0,
    this.recoveryDepth = 0.75,
  });

  final String name;
  final double aggressionAdjustment;
  final double recoveryDepth;
}

class BotPerception {
  const BotPerception({
    required this.ballX,
    required this.ballY,
    required this.ballZ,
    required this.ballVelocityX,
    required this.ballVelocityY,
    required this.ballVelocityZ,
    required this.ballHasBounced,
    required this.opponentX,
    required this.gravity,
  });

  final double ballX;
  final double ballY;
  final double ballZ;
  final double ballVelocityX;
  final double ballVelocityY;
  final double ballVelocityZ;
  final bool ballHasBounced;
  final double opponentX;
  final double gravity;
}

class BotMovementTarget {
  const BotMovementTarget(this.x, this.y);

  final double x;
  final double y;
}

class BotShotPlan {
  const BotShotPlan({
    required this.type,
    required this.targetX,
    required this.targetY,
    required this.velocityY,
    required this.lift,
  });

  final BotShotType type;
  final double targetX;
  final double targetY;
  final double velocityY;
  final double lift;

  double get forwardSpeed => velocityY.abs();
}

class BotAgent {
  BotAgent({
    required this.id,
    required this.side,
    required this.difficulty,
    required this.personality,
    required int randomSeed,
  }) : _random = math.Random(randomSeed) {
    aggression = (settings.aggression + personality.aggressionAdjustment)
        .clamp(0.0, 1.0);
    targetY = recoveryY;
  }

  final String id;
  final BotCourtSide side;
  final BotDifficulty difficulty;
  final BotPersonality personality;
  final math.Random _random;

  double aggression = 0;
  double targetX = 0;
  double targetY = 0;
  double reactionTimer = 0;
  double dashTimer = 0;
  double dashCooldown = 0;
  bool isDashing = false;

  BotDifficultySettings get settings => switch (difficulty) {
    BotDifficulty.easy => const BotDifficultySettings(
        reactionTicks: 16.0,
        moveSpeed: 0.012,
        dashSpeed: 0.040,
        aggression: 0.20,
        errorRate: 0.10,
        aimError: 0.080,
      ),
    BotDifficulty.normal => const BotDifficultySettings(
        reactionTicks: 10.0,
        moveSpeed: 0.015,
        dashSpeed: 0.050,
        aggression: 0.45,
        errorRate: 0.05,
        aimError: 0.040,
      ),
    BotDifficulty.hard => const BotDifficultySettings(
        reactionTicks: 5.0,
        moveSpeed: 0.019,
        dashSpeed: 0.060,
        aggression: 0.72,
        errorRate: 0.02,
        aimError: 0.015,
      ),
  };

  double get recoveryY => side == BotCourtSide.top
      ? -personality.recoveryDepth
      : personality.recoveryDepth;

  bool isBallIncoming(double velocityY) => side == BotCourtSide.top
      ? velocityY < 0
      : velocityY > 0;

  bool shouldThink() {
    if (reactionTimer > 0) {
      reactionTimer--;
      return false;
    }
    reactionTimer = settings.reactionTicks;
    return true;
  }

  void chooseMovementTarget(BotPerception perception) {
    if (!isBallIncoming(perception.ballVelocityY)) {
      targetX = 0;
      targetY = recoveryY;
      return;
    }

    final bounce = _predictBounce(perception);
    targetX = bounce.x.clamp(
      -PickleballRules.courtWidth * 0.95,
      PickleballRules.courtWidth * 0.95,
    );

    if (aggression > 0.5 && perception.ballHasBounced) {
      targetY = side == BotCourtSide.top
          ? -PickleballRules.kitchenDepth
          : PickleballRules.kitchenDepth;
      return;
    }

    final behindBounce = side == BotCourtSide.top
        ? bounce.y - 0.12
        : bounce.y + 0.12;
    targetY = side == BotCourtSide.top
        ? behindBounce.clamp(
            -PickleballRules.courtLength * 0.98,
            -PickleballRules.kitchenDepth - 0.05,
          )
        : behindBounce.clamp(
            PickleballRules.kitchenDepth + 0.05,
            PickleballRules.courtLength * 0.98,
          );
  }

  void updateDash({required double distance, required bool ballIncoming}) {
    if (dashCooldown > 0) dashCooldown--;
    if (dashTimer > 0) {
      dashTimer--;
      isDashing = true;
      return;
    }

    isDashing = false;
    if (ballIncoming && distance > 0.6 && dashCooldown <= 0) {
      dashTimer = 12.0;
      dashCooldown = 80.0;
      isDashing = true;
    }
  }

  BotShotPlan chooseShot(BotPerception perception) {
    final BotShotType shotType;
    if (perception.ballZ >= 0.36) {
      shotType = BotShotType.smash;
    } else if (perception.ballZ >= 0.12 && aggression >= 0.55) {
      shotType = BotShotType.drive;
    } else {
      shotType = BotShotType.safeReturn;
    }

    final openCourtDirection = perception.opponentX >= 0 ? -1.0 : 1.0;
    final targetWidth = switch (shotType) {
      BotShotType.safeReturn => 0.45,
      BotShotType.drive => 0.68,
      BotShotType.smash => 0.78,
    };
    final targetX = openCourtDirection *
        PickleballRules.courtWidth *
        targetWidth;
    final direction = side == BotCourtSide.top ? 1.0 : -1.0;

    return switch (shotType) {
      BotShotType.safeReturn => _buildShotPlan(
          perception: perception,
          type: shotType,
          targetX: targetX,
          targetY: direction * 0.70,
          speed: 0.024,
          netClearance: 0.055,
        ),
      BotShotType.drive => _buildShotPlan(
          perception: perception,
          type: shotType,
          targetX: targetX,
          targetY: direction * 0.82,
          speed: 0.030,
          netClearance: 0.030,
        ),
      BotShotType.smash => _buildShotPlan(
          perception: perception,
          type: shotType,
          targetX: targetX,
          targetY: direction * 0.88,
          speed: 0.036,
          netClearance: 0.015,
        ),
    };
  }

  BotShotPlan _buildShotPlan({
    required BotPerception perception,
    required BotShotType type,
    required double targetX,
    required double targetY,
    required double speed,
    required double netClearance,
  }) {
    final direction = side == BotCourtSide.top ? 1.0 : -1.0;
    final velocityY = direction * speed;
    final flightTicks = ((targetY - perception.ballY).abs() / speed)
        .clamp(12.0, 90.0);

    // Choose vertical velocity from the desired landing depth, then raise it
    // if necessary to guarantee clearance over the net from this contact.
    final landingLift =
        (0.5 * perception.gravity * flightTicks * flightTicks -
                perception.ballZ) /
            flightTicks;
    final netTicks = (perception.ballY.abs() / speed)
        .clamp(1.0, flightTicks);
    final clearanceLift =
        (PickleballRules.netHeight + netClearance - perception.ballZ +
                0.5 * perception.gravity * netTicks * netTicks) /
            netTicks;
    final lift = math.max(0.006, math.max(landingLift, clearanceLift));

    return BotShotPlan(
      type: type,
      targetX: targetX,
      targetY: targetY,
      velocityY: velocityY,
      lift: lift,
    );
  }

  bool rollError() => _random.nextDouble() < settings.errorRate;

  double nextAimOffset() =>
      (_random.nextDouble() - 0.5) * settings.aimError * 2.0;

  void reset() {
    targetX = 0;
    targetY = recoveryY;
    reactionTimer = 0;
    dashTimer = 0;
    dashCooldown = 0;
    isDashing = false;
  }

  BotMovementTarget _predictBounce(BotPerception perception) {
    var predictedX = perception.ballX;
    var predictedY = perception.ballY;
    var predictedZ = perception.ballZ;
    var predictedVelocityZ = perception.ballVelocityZ;

    for (var tick = 0; tick < 160 && predictedZ > 0; tick++) {
      predictedX += perception.ballVelocityX;
      predictedY += perception.ballVelocityY;
      predictedZ += predictedVelocityZ;
      predictedVelocityZ -= perception.gravity;
    }

    return BotMovementTarget(predictedX, predictedY);
  }
}
