import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vmath;

import 'bot_agent.dart';
import 'game_debug_config.dart';
import 'match_state.dart';
import 'pickleball_rules.dart';

export 'bot_agent.dart';

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
  double freeRoamY = 1.4;
  double freeRoamZ = 1.8;
  double freeRoamYaw = math.pi; // looking at -Y
  double freeRoamPitch = -0.35; // looking slightly down

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

  void updateDynamics({
    required double dt,
    required double ballX,
    required double ballY,
    required double playerX,
    required double playerY,
    required GameMode gameMode,
  }) {
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
      // Smoothly track the ball position for normal match and spectator
      targetEyeX = ballX * 0.15;
      targetLookX = ballX * 0.05;
      targetEyeY = (ballY * 0.10).clamp(-0.15, 0.15);
      targetLookY = (ballY * 0.20).clamp(-0.25, 0.25);
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
        eye = vmath.Vector3(
          eyeOffsetX + shakeX,
          1.8 + eyeOffsetY + shakeY,
          1.0,
        );
        target = vmath.Vector3(targetOffsetX, -0.2 + targetOffsetY, 0.0);
        break;
      case CameraMode.broadcast:
        // Zoomed-in tournament sideline broadcast view with subtle rally tracking
        eye = vmath.Vector3(1.35 + shakeX, eyeOffsetY + shakeY, 0.78);
        target = vmath.Vector3(0.0, targetOffsetY * 0.5, 0.08);
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
        // Top-down framing where the court fills the view comfortably with clearance for top HUD
        eye = vmath.Vector3(shakeX, shakeY - 0.12, 2.65);
        target = vmath.Vector3(0.0, -0.12, 0.0);
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

enum ShotQuality { early, good, perfect }

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
  const GameplayEvent(
    this.type, {
    this.side,
    this.isSmash = false,
    this.shotQuality,
    this.botShotType,
    this.botId,
  });

  final GameplayEventType type;
  final MatchSide? side;
  final bool isSmash;
  final ShotQuality? shotQuality;
  final BotShotType? botShotType;
  final String? botId;
}

enum GameMode { playerVsBot, botVsBot, freeRoamPractice }

enum PracticeDrill { dinks, drives, lobs, random }

class PracticeTarget {
  const PracticeTarget({
    required this.name,
    required this.x,
    required this.y,
    required this.radius,
    required this.points,
  });

  final String name;
  final double x;
  final double y;
  final double radius;
  final int points;
}

enum MapType { stadium, practiceFacility }

class GameSimulation {
  GameSimulation({
    this.gameMode = GameMode.playerVsBot,
    this.mapType = MapType.stadium,
    this.botDifficulty = BotDifficulty.normal,
  }) : topBotAgent = BotAgent(
         id: 'top-bot',
         side: BotCourtSide.top,
         difficulty: botDifficulty,
         personality: const BotPersonality(name: 'Steady'),
         randomSeed: 101,
       ),
       bottomBotAgent = BotAgent(
         id: 'bottom-bot',
         side: BotCourtSide.bottom,
         difficulty: botDifficulty,
         personality: const BotPersonality(
           name: 'Attacker',
           aggressionAdjustment: 0.20,
         ),
         randomSeed: 202,
       ) {
    if (gameMode == GameMode.freeRoamPractice) {
      playPhase = MatchPlayPhase.inRally;
      rallyPhase = RallyPhase.openRally;
    }
  }

  // --- Practice Facility State ---
  PracticeDrill practiceDrill = PracticeDrill.random;
  bool practiceAutoFeed = true;
  double practiceFeedIntervalSeconds = 2.8;
  int practiceStreak = 0;
  int practiceBestStreak = 0;
  int practiceScore = 0;
  int practiceTargetHits = 0;

  static const List<PracticeTarget> practiceTargets = [
    PracticeTarget(name: 'Deep Left', x: -0.28, y: -0.85, radius: 0.22, points: 100),
    PracticeTarget(name: 'Deep Right', x: 0.28, y: -0.85, radius: 0.22, points: 100),
    PracticeTarget(name: 'Deep Center', x: 0.0, y: -0.88, radius: 0.24, points: 75),
    PracticeTarget(name: 'Kitchen Drop L', x: -0.24, y: -0.22, radius: 0.20, points: 50),
    PracticeTarget(name: 'Kitchen Drop R', x: 0.24, y: -0.22, radius: 0.20, points: 50),
  ];

  int activeTargetIndex = 0;
  PracticeTarget get activeTarget =>
      practiceTargets[activeTargetIndex % practiceTargets.length];

  void Function(String targetName, int points)? onPracticeTargetHit;
  void Function()? onPracticeBallFired;

  // --- Net Cloth Collision & Deformation State ---
  double netImpactX = 0.0;
  double netImpactIntensity = 0.0;
  double netImpactDirection = 0.0;
  void Function()? onNetHit;

  final GameMode gameMode;
  final MapType mapType;
  final BotDifficulty botDifficulty;
  final BotAgent topBotAgent;
  final BotAgent bottomBotAgent;
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

  double get bot2ReactionTimer => bottomBotAgent.reactionTimer;
  set bot2ReactionTimer(double value) => bottomBotAgent.reactionTimer = value;
  double get bot2TargetX => bottomBotAgent.targetX;
  set bot2TargetX(double value) => bottomBotAgent.targetX = value;
  double get bot2TargetY => bottomBotAgent.targetY;
  set bot2TargetY(double value) => bottomBotAgent.targetY = value;

  double botX = 0;
  double botY = -0.75;

  /// Called when the player dashes — passes (x, y) position.
  void Function(double x, double y)? onPlayerDash;

  void dashPlayer() {
    if (gameMode == GameMode.botVsBot) return;
    if (playPhase != MatchPlayPhase.inRally &&
        playPhase != MatchPlayPhase.waitingForServe) {
      return;
    }

    if (playerVelocityX.abs() < 0.005 && playerVelocityY.abs() < 0.005) {
      playerVelocityY = -0.15;
    } else {
      playerVelocityX *= 3.5;
      playerVelocityY *= 3.5;

      final speed = math.sqrt(
        playerVelocityX * playerVelocityX + playerVelocityY * playerVelocityY,
      );
      if (speed > 0.25) {
        playerVelocityX = (playerVelocityX / speed) * 0.25;
        playerVelocityY = (playerVelocityY / speed) * 0.25;
      }
    }
    onPlayerDash?.call(playerX, playerY);
  }

  // Directional player hitbox, tightly fitted to character and elongated paddle reach.
  double playerHitRadiusX = 0.26;
  double playerHitFrontY = 0.24; // In front towards net (ball.y < playerY)
  double playerHitBackY = 0.18; // Behind player (ball.y > playerY)
  double playerHitZMin = 0.0;
  double playerHitZMax = 0.52; // Realistic overhead reach (net height 0.1364; prevents hitting high in the sky)

  // Directional bot hitbox (forward is toward the net: ball.y > botY).
  double botHitRadiusX = 0.26;
  double botHitFrontY = 0.24;
  double botHitBackY = 0.18;
  double botHitZMin = 0.0;
  double botHitZMax = 0.52;
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
    final receiver = servingSide == MatchSide.player
        ? MatchSide.bot
        : MatchSide.player;

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

  RallyEnd _endRally(RallyEnd result, {GameplayEventType? cause}) {
    playPhase = MatchPlayPhase.deadBall;
    rallyPhase = RallyPhase.deadBall;
    final faultSide = result == RallyEnd.playerFault
        ? MatchSide.player
        : MatchSide.bot;
    if (cause != null) {
      _emit(GameplayEvent(cause, side: faultSide));
    }
    _emit(GameplayEvent(GameplayEventType.rallyEnd, side: faultSide));
    return result;
  }

  ShotQuality _playerShotQuality() {
    final dx = (ball.x - playerX).abs() / playerHitRadiusX;
    final dy = (playerY - ball.y).abs() / playerHitFrontY;
    final contactError = math.max(dx, dy);

    if (contactError <= 0.28) return ShotQuality.perfect;
    if (contactError <= 0.62) return ShotQuality.good;
    return ShotQuality.early;
  }

  void _executePlayerHit({double joystickX = 0.0, double joystickY = 0.0}) {
    _recordHit(hitter: MatchSide.player);
    lastHitByPlayer = true;

    final quality = _playerShotQuality();
    final isSmash = ball.z > 0.3;
    final qualityPower = switch (quality) {
      ShotQuality.perfect => 1.10,
      ShotQuality.good => 1.0,
      ShotQuality.early => 0.88,
    };

    _emit(
      GameplayEvent(
        GameplayEventType.playerHit,
        side: MatchSide.player,
        isSmash: isSmash,
        shotQuality: quality,
      ),
    );

    debugPrint(
      '[DATA] ${jsonEncode({
        'type': 'action',
        'action': 'player_swing',
        'quality': quality.name,
        'rallyLength': rallyLength,
        'ball': {'x': ball.x, 'y': ball.y, 'z': ball.z},
      })}',
    );

    // Vertical joystick aim controls depth. Up aims deeper into the opponent
    // court; down pulls the shot shorter. With no input, aim safely deep.
    final depthInput = joystickY.abs() > 0.15 ? joystickY : 0.0;
    final targetCourtY = (-0.70 + depthInput * 0.22).clamp(-0.92, -0.42);

    double targetCourtX = 0.0;
    if (ball.x.abs() > 0.08) {
      targetCourtX = -ball.x.sign * 0.12 - ball.x * 0.25;
    }
    if (joystickX.abs() > 0.15) {
      targetCourtX = joystickX * (courtWidth * 0.78);
    }
    targetCourtX = targetCourtX.clamp(-courtWidth * 0.88, courtWidth * 0.88);

    final baseForwardSpeed = isSmash ? 0.034 : 0.024;
    ball.velocityY = -baseForwardSpeed * qualityPower;

    // A smash is flatter. Normal shots retain enough arc for safe clearance.
    ball.velocityZ = isSmash
        ? 0.009 * qualityPower
        : 0.022 * (2.0 - qualityPower);

    final ticks = ((ball.y - targetCourtY).abs() / ball.velocityY.abs()).clamp(
      18.0,
      90.0,
    );
    ball.velocityX = (targetCourtX - ball.x) / ticks;
    ball.hasBounced = false;

    if (gameMode == GameMode.freeRoamPractice) {
      ballMachineTimer = math.max(ballMachineTimer, 75.0);
    }
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

  bool get _serverStartsOnLeft => currentServerScore.isOdd;
  double get _servePositionX => _serverStartsOnLeft ? -0.25 : 0.25;
  double get _serveTargetX => _serverStartsOnLeft ? 0.227 : -0.227;

  void resetRally({
    MatchSide servingSide = MatchSide.bot,
    int serverScore = 0,
  }) {
    if (gameMode == GameMode.freeRoamPractice) {
      playPhase = MatchPlayPhase.inRally;
      rallyPhase = RallyPhase.openRally;
      lastHitByPlayer = false;
      ballMachineTimer = 40.0;
      return;
    }

    this.servingSide = servingSide;
    currentServerScore = serverScore;
    lastHitByPlayer = servingSide == MatchSide.player;
    playPhase = MatchPlayPhase.waitingForServe;
    rallyPhase = RallyPhase.waitingForServe;
    rallyLength = 0;
    _events.clear();
    netImpactIntensity = 0.0;
    netImpactX = 0.0;
    netImpactDirection = 0.0;

    ball.velocityZ = 0;
    ball.velocityY = 0;
    ball.velocityX = 0;
    ball.hasBounced = false;
    botServeTimer = 60.0;
    bot2ServeTimer = 60.0;
    topBotAgent.reset();
    bottomBotAgent.reset();
    playerVelocityX = 0;
    playerVelocityY = 0;
    playerServeAimAngle = 0.0;
    playerSwingActiveTimer = 0.0;
    if (servingSide == MatchSide.player) {
      playerX = _servePositionX;
    } else {
      botX = _servePositionX;
    }
    ball.x = 0;
    ball.y = -1.05;
    ball.z = 0.12;
  }

  double botServeTimer = 0.0;
  double bot2ServeTimer = 0.0;
  double get botTargetX => topBotAgent.targetX;
  set botTargetX(double value) => topBotAgent.targetX = value;
  double get botTargetY => topBotAgent.targetY;
  set botTargetY(double value) => topBotAgent.targetY = value;
  double get botReactionTimer => topBotAgent.reactionTimer;
  set botReactionTimer(double value) => topBotAgent.reactionTimer = value;
  double get botDashTimer => topBotAgent.dashTimer;
  set botDashTimer(double value) => topBotAgent.dashTimer = value;
  double get botDashCooldown => topBotAgent.dashCooldown;
  set botDashCooldown(double value) => topBotAgent.dashCooldown = value;
  bool get botIsDashing => topBotAgent.isDashing;
  set botIsDashing(bool value) => topBotAgent.isDashing = value;

  // Bot Personality (Aggression 0.0 = Defensive, 1.0 = Aggressive)
  double get bot1Aggression => topBotAgent.aggression;
  set bot1Aggression(double value) => topBotAgent.aggression = value;
  double get bot2Aggression => bottomBotAgent.aggression;
  set bot2Aggression(double value) => bottomBotAgent.aggression = value;
  double get bot2DashCooldown => bottomBotAgent.dashCooldown;
  set bot2DashCooldown(double value) => bottomBotAgent.dashCooldown = value;
  bool get bot2IsDashing => bottomBotAgent.isDashing;
  set bot2IsDashing(bool value) => bottomBotAgent.isDashing = value;

  double ballMachineTimer = 100.0;

  void launchBallMachine({PracticeDrill? drill}) {
    if (gameMode != GameMode.freeRoamPractice) return;

    final selectedDrill = drill ?? practiceDrill;
    final effectiveDrill = selectedDrill == PracticeDrill.random
        ? switch (math.Random().nextInt(3)) {
            0 => PracticeDrill.dinks,
            1 => PracticeDrill.drives,
            _ => PracticeDrill.lobs,
          }
        : selectedDrill;

    ball.x = 0;
    ball.y = -courtLength;
    ball.z = 0.45;
    ball.hasBounced = false;
    lastHitByPlayer = false;

    // Lateral target variance within playable bounds
    final lateralSpread = (math.Random().nextDouble() - 0.5) * 0.40;
    final targetX = (playerX * 0.6 + lateralSpread).clamp(
      -courtWidth * 0.85,
      courtWidth * 0.85,
    );

    switch (effectiveDrill) {
      case PracticeDrill.dinks:
        // Soft drop shot landing near the kitchen line (y ~ 0.28 to 0.42)
        final targetY = 0.28 + math.Random().nextDouble() * 0.14;
        final dx = targetX - ball.x;
        final dy = targetY - ball.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        const speed = 0.021;
        ball.velocityX = (dx / dist) * speed;
        ball.velocityY = (dy / dist) * speed;
        ball.velocityZ = 0.016; // gentle arch
        break;

      case PracticeDrill.drives:
        // Fast, penetrating baseline drive (y ~ 0.70 to 0.90)
        final targetY = 0.70 + math.Random().nextDouble() * 0.20;
        final dx = targetX - ball.x;
        final dy = targetY - ball.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        const speed = 0.031;
        ball.velocityX = (dx / dist) * speed;
        ball.velocityY = (dy / dist) * speed;
        ball.velocityZ = 0.019; // low clearing trajectory
        break;

      case PracticeDrill.lobs:
        // High arcing ball landing deep (y ~ 0.78 to 0.95), great for smashes
        final targetY = 0.78 + math.Random().nextDouble() * 0.18;
        final dx = targetX - ball.x;
        final dy = targetY - ball.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        const speed = 0.022;
        ball.velocityX = (dx / dist) * speed;
        ball.velocityY = (dy / dist) * speed;
        ball.velocityZ = 0.033; // high arc
        break;

      case PracticeDrill.random:
        break;
    }

    ballMachineTimer = practiceFeedIntervalSeconds * 40.0;
    onPracticeBallFired?.call();
    _emit(const GameplayEvent(GameplayEventType.bounce));
  }

  BotDifficultySettings get difficultySettings => topBotAgent.settings;

  BotPerception _botPerception({required double opponentX}) => BotPerception(
    ballX: ball.x,
    ballY: ball.y,
    ballZ: ball.z,
    ballVelocityX: ball.velocityX,
    ballVelocityY: ball.velocityY,
    ballVelocityZ: ball.velocityZ,
    ballHasBounced: ball.hasBounced,
    opponentX: opponentX,
    gravity: gravity,
  );

  BotShotPlan chooseBotShot() =>
      topBotAgent.chooseShot(_botPerception(opponentX: playerX));

  BotShotPlan chooseBottomBotShot() =>
      bottomBotAgent.chooseShot(_botPerception(opponentX: botX));

  ({
    List<({double x, double y, double z})> points,
    double targetX,
    double targetY,
    bool isLegal,
  })
  getPlayerServeTrajectory() {
    final baseTargetX = _serveTargetX;
    final targetX = (baseTargetX + math.sin(playerServeAimAngle) * 0.22).clamp(
      -courtWidth * 0.95,
      courtWidth * 0.95,
    );
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
      serveFromLeft: _serverStartsOnLeft,
    );

    return (
      points: points,
      targetX: targetX,
      targetY: targetY,
      isLegal: isLegal,
    );
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
      final targetX = _serveTargetX;
      final targetY = 0.66;
      const double T = 52.0;
      ball.velocityX = (targetX - (botX + 0.08)) / T;
      ball.velocityY = (targetY - (botY + 0.04)) / T;
      ball.velocityZ = (0.5 * gravity * T * T - 0.12) / T;
      lastHitByPlayer = false;
    }
  }

  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {
    var ballBouncedThisTick = false;

    if (netImpactIntensity > 0) {
      netImpactIntensity = math.max(0.0, netImpactIntensity - 0.04);
    }

    _telemetryTimer += 0.025;
    if (_telemetryTimer >= 0.5) {
      _telemetryTimer = 0.0;
      final telemetryData = {
        'type': 'telemetry',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'bot': {
          'x': double.parse(botX.toStringAsFixed(3)),
          'y': double.parse(botY.toStringAsFixed(3)),
        },
        'botTarget': {
          'x': double.parse(botTargetX.toStringAsFixed(3)),
          'y': double.parse(botTargetY.toStringAsFixed(3)),
        },
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

      // Constrain free roam strictly inside stadium boundaries
      final maxW = courtWidth * 2.5; // ~1.10 (inside arena walls)
      final minY = -courtLength * 2.0; // inside grandstand back wall (-2.8)
      final maxY = courtLength * 1.55; // inside front arena boundary
      camera.freeRoamX = camera.freeRoamX.clamp(-maxW, maxW);
      camera.freeRoamY = camera.freeRoamY.clamp(minY, maxY);
      camera.freeRoamZ = camera.freeRoamZ.clamp(0.4, 2.8);

      camera._updateMatrices();
      jX = 0;
      jY = 0;
    }

    if (playPhase == MatchPlayPhase.waitingForServe) {
      final isEven = currentServerScore % 2 == 0;
      final serveX = _servePositionX;

      if (servingSide == MatchSide.player) {
        // Player stands completely outside the baseline (Y > courtLength)
        final baselineServeY = courtLength + 0.08;

        if (gameMode == GameMode.playerVsBot) {
          if (jX.abs() > 0.05) {
            // Interactive serve aiming and positioning outside the court
            playerServeAimAngle = (playerServeAimAngle + jX * 0.025).clamp(
              -0.45,
              0.45,
            );
            playerX += jX * 0.008;
          }
          playerX = isEven
              ? playerX.clamp(0.06, courtWidth)
              : playerX.clamp(-courtWidth, -0.06);
        } else {
          playerX += (serveX - playerX) * 0.1;
        }

        // Position player outside the baseline
        playerY += (baselineServeY - playerY) * 0.15;
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
          playerX = (playerX + playerVelocityX).clamp(
            -courtWidth * 1.25,
            courtWidth * 1.25,
          );
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
      if (netImpactIntensity > 0) {
        netImpactIntensity = math.max(0.0, netImpactIntensity - 0.04);
      }
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
        ballY: ball.y,
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
        playerX = (playerX + playerVelocityX).clamp(
          -courtWidth * 1.25,
          courtWidth * 1.25,
        );
        playerY = (playerY + playerVelocityY).clamp(0.05, courtLength * 1.35);
      }
      return null;
    }

    final previousBallY = ball.y;

    // Buffered swing for player: connects cleanly when player swings slightly early
    if (gameMode != GameMode.botVsBot && playerSwingActiveTimer > 0) {
      playerSwingActiveTimer -= 0.025;
      if (ball.velocityY > 0 && canPlayerHitBall()) {
        if (gameMode != GameMode.freeRoamPractice &&
            !GameDebugConfig.bypassKitchenRules) {
          if (PickleballRules.isKitchenVolley(
            playerY: playerY,
            ballHasBounced: ball.hasBounced,
          )) {
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
        _executePlayerHit(joystickX: jX, joystickY: jY);
        onPlayerHit?.call(isSmash);
      }
    }

    if (gameMode == GameMode.botVsBot) {
      final bottomPerception = _botPerception(opponentX: botX);
      if (bottomBotAgent.shouldThink()) {
        bottomBotAgent.chooseMovementTarget(bottomPerception);
      }

      final dx = bot2TargetX - playerX;
      final dy = bot2TargetY - playerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      bottomBotAgent.updateDash(
        distance: dist,
        ballIncoming: bottomBotAgent.isBallIncoming(ball.velocityY),
      );

      final bottomSpeed = bot2IsDashing
          ? bottomBotAgent.settings.dashSpeed
          : bottomBotAgent.settings.moveSpeed;
      if (dist > 0.02) {
        final step = math.min(bottomSpeed, dist);
        playerX += (dx / dist) * step;
        playerY += (dy / dist) * step;
      }
      playerX = playerX.clamp(-courtWidth * 1.25, courtWidth * 1.25);
      playerY = playerY.clamp(0.05, courtLength * 1.35);
      playerVelocityX = 0;
      playerVelocityY = 0;
      jX = 0;
      jY = 0;

      // Auto-hit
      if (ball.velocityY > 0 && canPlayerHitBall()) {
        if (!isTwoBounceViolation(forPlayer: true)) {
          _recordHit(hitter: MatchSide.player);
          lastHitByPlayer = true;

          final shotPlan = bottomBotAgent.chooseShot(bottomPerception);
          final isSmash = shotPlan.type == BotShotType.smash;
          final isError = bottomBotAgent.rollError();
          _emit(
            GameplayEvent(
              GameplayEventType.botHit,
              side: MatchSide.player,
              isSmash: isSmash,
              botShotType: shotPlan.type,
              botId: bottomBotAgent.id,
            ),
          );

          ball.velocityY = shotPlan.velocityY;
          if (isError) {
            ball.velocityZ = 0.005;
            ball.velocityX = (ball.x - playerX) * 0.12 - 0.02;
          } else {
            ball.velocityZ = shotPlan.lift;
            final ticks =
                ((shotPlan.targetY - ball.y).abs() / ball.velocityY.abs())
                    .clamp(20.0, 90.0);
            final targetX = (shotPlan.targetX + bottomBotAgent.nextAimOffset())
                .clamp(-courtWidth * 0.85, courtWidth * 0.85);
            ball.velocityX = (targetX - ball.x) / ticks;
          }
          ball.hasBounced = false;
        }
      }
    }

    // Smooth character movement (inertia/momentum)
    final targetVelX = jX * moveSpeed;
    final targetVelY = jY * moveSpeed;
    final friction = gameMode == GameMode.freeRoamPractice ? 0.05 : 0.15;
    playerVelocityX += (targetVelX - playerVelocityX) * friction;
    playerVelocityY += (targetVelY - playerVelocityY) * friction;

    if (gameMode == GameMode.freeRoamPractice) {
      playerX = (playerX + playerVelocityX).clamp(
        -courtWidth * 5.0,
        courtWidth * 5.0,
      );
      playerY = (playerY + playerVelocityY).clamp(
        -courtLength * 5.0,
        courtLength * 5.0,
      );
    } else {
      playerX = (playerX + playerVelocityX).clamp(
        -courtWidth * 1.25,
        courtWidth * 1.25,
      );
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
            final isCorrect = PickleballRules.isServeInCorrectBox(
              x: ball.x,
              y: ball.y,
              playerServing: servingSide == MatchSide.player,
              serveFromLeft: _serverStartsOnLeft,
            );
            if (!isCorrect) {
              return _endRally(
                servingSide == MatchSide.player
                    ? RallyEnd.playerFault
                    : RallyEnd.botFault,
                cause: GameplayEventType.outOfBounds,
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
        ballBouncedThisTick = true;
        _emit(
          GameplayEvent(
            GameplayEventType.bounce,
            side: ball.y > 0 ? MatchSide.player : MatchSide.bot,
          ),
        );
        ball.z = 0;
        ball.velocityZ = 0.018;
      } else {
        if (!ball.hasBounced) {
          ballBouncedThisTick = true;
          _emit(
            GameplayEvent(
              GameplayEventType.bounce,
              side: ball.y > 0 ? MatchSide.player : MatchSide.bot,
            ),
          );

          // Check if player returned the ball into the opponent court
          if (lastHitByPlayer && ball.y < 0) {
            final isLegalIn = PickleballRules.isInsideCourt(ball.x, ball.y);
            if (isLegalIn) {
              practiceStreak++;
              if (practiceStreak > practiceBestStreak) {
                practiceBestStreak = practiceStreak;
              }

              // Check target zone hit
              final target = activeTarget;
              final tDx = ball.x - target.x;
              final tDy = ball.y - target.y;
              if (tDx * tDx + tDy * tDy <= target.radius * target.radius) {
                final multiplier = practiceStreak >= 10
                    ? 2.0
                    : (practiceStreak >= 5 ? 1.5 : 1.0);
                final awardedPoints = (target.points * multiplier).round();
                practiceScore += awardedPoints;
                practiceTargetHits++;
                onPracticeTargetHit?.call(target.name, awardedPoints);
                activeTargetIndex =
                    (activeTargetIndex + 1) % practiceTargets.length;
              }
            } else {
              practiceStreak = 0;
            }
          }
        }

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

    // Net Collision (Cloth physics: absorbs horizontal kinetic energy, gentle rebound, slides down net)
    final crossedNetPlane = (previousBallY < 0 && ball.y >= 0) ||
        (previousBallY > 0 && ball.y <= 0);
    final isWithinNetHeight =
        ball.z < PickleballRules.netHeight && ball.z >= 0;
    final isWithinNetWidth = ball.x.abs() <= courtWidth * 1.15;

    if (crossedNetPlane && isWithinNetHeight && isWithinNetWidth) {
      final fromPlayerSide = previousBallY > 0;

      // Cloth impact deflection parameters for visual ripple
      netImpactX = ball.x;
      netImpactIntensity = (ball.velocityY.abs() * 35.0).clamp(0.4, 1.2);
      netImpactDirection = fromPlayerSide ? -1.0 : 1.0;

      // Keep ball on incoming side of the net (do not phase through)
      ball.y = fromPlayerSide ? 0.025 : -0.025;

      // Cloth absorbs ~88% of forward kinetic energy, producing a gentle rebound
      ball.velocityY = -ball.velocityY * 0.12;

      // Lateral friction against mesh cloth
      ball.velocityX *= 0.35;

      // Damped vertical velocity - slides down the net towards the floor
      ball.velocityZ = (ball.velocityZ * 0.20).clamp(-0.01, 0.006);

      onNetHit?.call();

      if (gameMode != GameMode.freeRoamPractice) {
        return _endRally(
          fromPlayerSide ? RallyEnd.playerFault : RallyEnd.botFault,
          cause: GameplayEventType.netFault,
        );
      } else {
        if (lastHitByPlayer && fromPlayerSide) {
          practiceStreak = 0;
        }
        _emit(const GameplayEvent(GameplayEventType.netFault));
      }
    }

    if (gameMode != GameMode.freeRoamPractice) {
      // Wide bleacher limits: only terminate when ball completely clears the arena
      if (!ball.hasBounced &&
          (ball.y.abs() > courtLength * 2.2 ||
              ball.x.abs() > courtWidth * 2.5)) {
        return _endRally(
          lastHitByPlayer ? RallyEnd.playerFault : RallyEnd.botFault,
          cause: GameplayEventType.outOfBounds,
        );
      }
    }

    if (gameMode == GameMode.freeRoamPractice) {
      if (practiceAutoFeed) {
        if (ballMachineTimer > 0) {
          ballMachineTimer--;
        } else {
          launchBallMachine();
        }
      }
    } else if (!GameDebugConfig.freezeAI) {
      final topPerception = _botPerception(opponentX: playerX);
      if (topBotAgent.shouldThink()) {
        topBotAgent.chooseMovementTarget(topPerception);
      }

      final dx = botTargetX - botX;
      final dy = botTargetY - botY;
      final dist = math.sqrt(dx * dx + dy * dy);

      final ballComingToBot = ball.velocityY < 0;
      final wasDashing = botIsDashing;
      topBotAgent.updateDash(distance: dist, ballIncoming: ballComingToBot);
      if (!wasDashing && botIsDashing) {
        debugPrint(
          '[DATA] ${jsonEncode({
            'type': 'action',
            'action': 'dash',
            'bot': {'x': botX, 'y': botY},
            'target': {'x': botTargetX, 'y': botTargetY},
            'distance': dist,
          })}',
        );
      }

      final double speed = botIsDashing
          ? difficultySettings.dashSpeed
          : difficultySettings.moveSpeed;

      // Move smoothly to target without overshooting/vibrating
      if (dist > 0.02) {
        final step = math.min(speed, dist);
        botX += (dx / dist) * step;
        botY += (dy / dist) * step;
      }
      botX = botX.clamp(-courtWidth * 1.25, courtWidth * 1.25);
      botY = botY.clamp(-courtLength * 1.35, -0.05);
    }

    // Do not let the bot return a ball on the exact physics tick it bounces.
    // Waiting until the next tick keeps the bounce and return as distinct
    // rally-state transitions and avoids a ground-level instant hit.
    if (!ballBouncedThisTick && ball.velocityY < 0 && canBotHitBall()) {
      if (isTwoBounceViolation(forPlayer: false)) {
        // Wait for bounce
      } else {
        _recordHit(hitter: MatchSide.bot);
        lastHitByPlayer = false;
        final shotPlan = topBotAgent.chooseShot(
          _botPerception(opponentX: playerX),
        );
        final isSmash = shotPlan.type == BotShotType.smash;
        final isError = topBotAgent.rollError();
        _emit(
          GameplayEvent(
            GameplayEventType.botHit,
            side: MatchSide.bot,
            isSmash: isSmash,
            botShotType: shotPlan.type,
            botId: topBotAgent.id,
          ),
        );

        debugPrint(
          '[DATA] ${jsonEncode({
            'type': 'action',
            'action': 'swing',
            'shotType': shotPlan.type.name,
            'error': isError,
            'rallyLength': rallyLength,
            'ball': {'x': ball.x, 'y': ball.y, 'z': ball.z},
          })}',
        );

        ball.velocityY = shotPlan.velocityY;

        if (isError) {
          ball.velocityZ = 0.005; // Hit the net!
          ball.velocityX =
              (ball.x - botX) * 0.12 + 0.02; // Or hit out of bounds
        } else {
          ball.velocityZ = shotPlan.lift;
          final ticks =
              ((shotPlan.targetY - ball.y).abs() / ball.velocityY.abs()).clamp(
                20.0,
                90.0,
              );
          final targetX = (shotPlan.targetX + topBotAgent.nextAimOffset())
              .clamp(-courtWidth * 0.85, courtWidth * 0.85);
          ball.velocityX = (targetX - ball.x) / ticks;
        }
        ball.hasBounced = false;
      }
    }

    camera.updateDynamics(
      dt: 0.025,
      ballX: ball.x,
      ballY: ball.y,
      playerX: playerX,
      playerY: playerY,
      gameMode: gameMode,
    );
    return null;
  }

  SwingResult swing({double joystickX = 0.0, double joystickY = 0.0}) {
    if (gameMode == GameMode.botVsBot) {
      return SwingResult.missed;
    }
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

    if (gameMode != GameMode.freeRoamPractice &&
        !GameDebugConfig.bypassKitchenRules) {
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
    _executePlayerHit(joystickX: joystickX, joystickY: joystickY);
    onPlayerHit?.call(isSmash);
    return SwingResult.hit;
  }

  double ballScale() => 1 + ball.z * 0.45;

  double ballShadowScale() => math.max(0.35, 1 - ball.z * 0.5);
}
