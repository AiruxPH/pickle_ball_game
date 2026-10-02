// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';

import 'package:pickle_ball_game/game_simulation.dart';
import 'package:pickle_ball_game/main.dart';
import 'package:pickle_ball_game/match_state.dart';
import 'package:pickle_ball_game/pickleball_flame_game.dart';
import 'package:pickle_ball_game/pickleball_rules.dart';
import 'package:pickle_ball_game/data/usap_rulebook_data.dart';
import 'package:pickle_ball_game/screens/main_menu_screen.dart';
import 'package:pickle_ball_game/screens/paddle_shop_screen.dart';
import 'package:pickle_ball_game/screens/rulebook_screen.dart';
import 'package:pickle_ball_game/screens/settings_screen.dart';
import 'package:pickle_ball_game/widgets/game_pause_overlay.dart';
import 'package:pickle_ball_game/widgets/match_complete_overlay.dart';
import 'package:pickle_ball_game/widgets/rulebook/glossary_card_widget.dart';
import 'package:pickle_ball_game/widgets/serve_rhythm_meter.dart';

void main() {
  test('court and match rules use shared boundaries', () {
    expect(PickleballRules.isInsideCourt(0, 0), isTrue);
    expect(PickleballRules.isInsideCourt(0.83, 0), isFalse);
    expect(PickleballRules.isWinningScore(11, 9), isTrue);
    expect(PickleballRules.isWinningScore(11, 10), isFalse);
    expect(
      PickleballRules.isServeInCorrectBox(
        x: 0.3,
        y: 0.4,
        playerServing: false,
        serveFromLeft: true,
      ),
      isTrue,
    );
    expect(
      PickleballRules.isServeInCorrectBox(
        x: -0.3,
        y: 0.4,
        playerServing: false,
        serveFromLeft: true,
      ),
      isFalse,
    );
    expect(
      PickleballRules.isKitchenVolley(playerY: 0.2, ballHasBounced: false),
      isTrue,
    );
    expect(
      PickleballRules.isKitchenVolley(playerY: 0.2, ballHasBounced: true),
      isFalse,
    );

    final serverFault = PickleballRules.resolveFault(
      playerScore: 3,
      botScore: 2,
      playerServing: true,
      playerAtFault: true,
    );
    expect(serverFault.playerScore, 3);
    expect(serverFault.botScore, 2);
    expect(serverFault.playerServing, isFalse);
    expect(serverFault.pointAwarded, isFalse);

    final receiverFault = PickleballRules.resolveFault(
      playerScore: 3,
      botScore: 2,
      playerServing: true,
      playerAtFault: false,
    );
    expect(receiverFault.playerScore, 4);
    expect(receiverFault.botScore, 2);
    expect(receiverFault.playerServing, isTrue);
    expect(receiverFault.pointAwarded, isTrue);

    final matchPoint = PickleballRules.resolveFault(
      playerScore: 10,
      botScore: 8,
      playerServing: true,
      playerAtFault: false,
    );
    expect(matchPoint.gameOver, isTrue);
  });

  test('simulation keeps mechanics independent from rendering', () {
    final simulation = GameSimulation();
    simulation.resetRally();
    final initialY = simulation.ball.y;

    final rallyEnd = simulation.update(joystickX: 1, joystickY: -1);

    expect(rallyEnd, isNull);
    expect(simulation.ball.y, greaterThan(initialY));
    expect(simulation.playerX, greaterThan(0));
    expect(simulation.playerY, lessThan(0.75));
    final projectedCenter = simulation.camera.project(x: 0, y: 0);
    expect(projectedCenter.x, 0);
    expect(
      simulation.camera.project(x: 0, y: -GameSimulation.courtLength).scale,
      lessThan(
        simulation.camera.project(x: 0, y: GameSimulation.courtLength).scale,
      ),
    );
    expect(simulation.ballScale(), greaterThan(1));
  });

  test('simulation enforces bounce, kitchen, and net constraints', () {
    final simulation = GameSimulation();
    simulation.playerX = 0;
    simulation.playerY = 0.2;
    simulation.ball
      ..x = 0
      ..y = 0.2
      ..z = 0.2
      ..hasBounced = false;

    expect(simulation.swing(), SwingResult.kitchenFault);

    simulation.ball
      ..y = -0.01
      ..z = PickleballRules.netHeight - 0.01
      ..velocityY = 0.02
      ..velocityZ = 0;
    expect(simulation.update(), RallyEnd.botFault);
  });

  test('player and bot hitboxes stay close to their racket reach', () {
    final simulation = GameSimulation();
    simulation.playerX = 0;
    simulation.playerY = 0.75;
    simulation.ball
      ..x = 0.25
      ..y = 0.52
      ..z = 0.50;
    expect(simulation.canPlayerHitBall(), isTrue);

    // Outside horizontal reach (radius 0.26)
    simulation.ball.x = 0.28;
    expect(simulation.canPlayerHitBall(), isFalse);
    simulation.ball.x = 0.25;

    // Too far in front (front reach 0.24)
    simulation.ball.y = 0.50;
    expect(simulation.canPlayerHitBall(), isFalse);
    simulation.ball.y = 0.52;

    // Unrealistic midair hit rejected (zMax 0.52)
    simulation.ball.z = 0.55;
    expect(simulation.canPlayerHitBall(), isFalse);
    simulation.ball.z = 0.84; // Old mid-air height
    expect(simulation.canPlayerHitBall(), isFalse);

    simulation.botX = 0;
    simulation.botY = -0.75;
    simulation.ball
      ..x = 0.25
      ..y = -0.52
      ..z = 0.50;
    expect(simulation.canBotHitBall(), isTrue);

    // Bot too far in front
    simulation.ball.y = -0.50;
    expect(simulation.canBotHitBall(), isFalse);

    // Bot mid-air ball in the sky rejected
    simulation.ball
      ..y = -0.52
      ..z = 0.84;
    expect(simulation.canBotHitBall(), isFalse);
  });

  test('rally state controls the two-bounce rule', () {
    final simulation = GameSimulation();

    simulation.resetRally(servingSide: MatchSide.player);
    expect(simulation.rallyPhase, RallyPhase.waitingForServe);

    simulation.triggerServe();
    expect(simulation.rallyPhase, RallyPhase.serveInFlight);
    expect(simulation.isTwoBounceViolation(forPlayer: false), isTrue);
    expect(simulation.isTwoBounceViolation(forPlayer: true), isFalse);

    // Simulate the legal serve bounce and receiver return.
    simulation.ball
      ..x = -0.25
      ..y = -0.65
      ..z = -0.001
      ..velocityX = 0
      ..velocityY = -0.001
      ..velocityZ = -0.01
      ..hasBounced = false;
    expect(simulation.update(), isNull);
    expect(simulation.rallyPhase, RallyPhase.receiverMayReturn);

    simulation.botX = simulation.ball.x;
    simulation.botY = simulation.ball.y;
    simulation.ball.velocityY = -0.01;
    simulation.update();
    expect(simulation.rallyPhase, RallyPhase.serverBounceRequired);
    expect(simulation.isTwoBounceViolation(forPlayer: true), isTrue);
    expect(simulation.isTwoBounceViolation(forPlayer: false), isFalse);
  });

  test('bot moves toward the predicted bounce instead of the current ball', () {
    final simulation = GameSimulation();
    simulation.botReactionTimer = 0;
    simulation.ball
      ..x = -0.2
      ..y = 0.6
      ..z = 0.45
      ..velocityX = 0.01
      ..velocityY = -0.02
      ..velocityZ = 0.01
      ..hasBounced = false;

    expect(simulation.update(), isNull);

    // The ball is still left of center, but its projected bounce is right of
    // center. The bot should move toward that future position.
    expect(simulation.ball.x, lessThan(0));
    expect(simulation.botTargetX, greaterThan(0.1));
  });

  test('bot recovers to center after returning the ball', () {
    final simulation = GameSimulation();
    simulation.botReactionTimer = 0;
    simulation.botTargetX = 0.3;
    simulation.botTargetY = -0.4;
    simulation.ball
      ..x = 0.2
      ..y = -0.5
      ..z = 0.4
      ..velocityX = 0
      ..velocityY = 0.02
      ..velocityZ = 0.01
      ..hasBounced = false;

    expect(simulation.update(), isNull);
    expect(simulation.botTargetX, 0);
    expect(simulation.botTargetY, -0.75);
  });

  test(
    'bot selects safe, drive, and smash plans from ball height and aggression',
    () {
      final simulation = GameSimulation();
      simulation.playerX = 0.3;
      simulation.ball.z = 0.2;
      simulation.bot1Aggression = 0.2;

      final safePlan = simulation.chooseBotShot();
      expect(safePlan.type, BotShotType.safeReturn);
      expect(safePlan.targetX, lessThan(0));

      simulation.bot1Aggression = 0.8;
      final drivePlan = simulation.chooseBotShot();
      expect(drivePlan.type, BotShotType.drive);
      expect(drivePlan.forwardSpeed, greaterThan(safePlan.forwardSpeed));

      simulation.ball.z = 0.5;
      final smashPlan = simulation.chooseBotShot();
      expect(smashPlan.type, BotShotType.smash);
      expect(smashPlan.forwardSpeed, greaterThan(drivePlan.forwardSpeed));
      expect(smashPlan.lift, lessThan(drivePlan.lift));
    },
  );

  test('bot aims toward the court space opposite the player', () {
    final simulation = GameSimulation();
    simulation.ball.z = 0.2;

    simulation.playerX = 0.3;
    final leftTarget = simulation.chooseBotShot().targetX;
    simulation.playerX = -0.3;
    final rightTarget = simulation.chooseBotShot().targetX;

    expect(leftTarget, lessThan(0));
    expect(rightTarget, greaterThan(0));
  });

  test('bot difficulty changes reaction, movement, accuracy, and errors', () {
    final easy = GameSimulation(botDifficulty: BotDifficulty.easy);
    final normal = GameSimulation(botDifficulty: BotDifficulty.normal);
    final hard = GameSimulation(botDifficulty: BotDifficulty.hard);

    expect(
      easy.difficultySettings.reactionTicks,
      greaterThan(normal.difficultySettings.reactionTicks),
    );
    expect(
      hard.difficultySettings.moveSpeed,
      greaterThan(normal.difficultySettings.moveSpeed),
    );
    expect(
      hard.difficultySettings.aggression,
      greaterThan(easy.difficultySettings.aggression),
    );
    expect(
      hard.difficultySettings.errorRate,
      lessThan(easy.difficultySettings.errorRate),
    );
    expect(
      hard.difficultySettings.aimError,
      lessThan(easy.difficultySettings.aimError),
    );
  });

  test('bot agents keep independent identity, personality, and memory', () {
    final simulation = GameSimulation(gameMode: GameMode.botVsBot);

    expect(simulation.topBotAgent.id, 'top-bot');
    expect(simulation.bottomBotAgent.id, 'bottom-bot');
    expect(
      simulation.bottomBotAgent.aggression,
      greaterThan(simulation.topBotAgent.aggression),
    );

    simulation.topBotAgent.reactionTimer = 7;
    simulation.bottomBotAgent.reactionTimer = 2;
    simulation.topBotAgent.targetX = -0.2;
    simulation.bottomBotAgent.targetX = 0.3;

    expect(simulation.topBotAgent.reactionTimer, 7);
    expect(simulation.bottomBotAgent.reactionTimer, 2);
    expect(simulation.topBotAgent.targetX, -0.2);
    expect(simulation.bottomBotAgent.targetX, 0.3);
  });

  test('shared bot reasoning mirrors shots for opposite court sides', () {
    const perception = BotPerception(
      ballX: 0,
      ballY: 0,
      ballZ: 0.2,
      ballVelocityX: 0,
      ballVelocityY: 0,
      ballVelocityZ: 0,
      ballHasBounced: true,
      opponentX: 0.25,
      gravity: GameSimulation.gravity,
    );
    final top = BotAgent(
      id: 'top',
      side: BotCourtSide.top,
      difficulty: BotDifficulty.normal,
      personality: const BotPersonality(name: 'top'),
      randomSeed: 1,
    );
    final bottom = BotAgent(
      id: 'bottom',
      side: BotCourtSide.bottom,
      difficulty: BotDifficulty.normal,
      personality: const BotPersonality(name: 'bottom'),
      randomSeed: 2,
    );

    final topShot = top.chooseShot(perception);
    final bottomShot = bottom.chooseShot(perception);

    expect(topShot.type, bottomShot.type);
    expect(topShot.targetX, bottomShot.targetX);
    expect(topShot.targetY, -bottomShot.targetY);
    expect(topShot.velocityY, -bottomShot.velocityY);
  });

  test('bottom bot emits its own identified hit event', () {
    final simulation = GameSimulation(gameMode: GameMode.botVsBot);
    simulation.rallyPhase = RallyPhase.openRally;
    simulation.ball
      ..x = simulation.playerX
      ..y = simulation.playerY
      ..z = 0.2
      ..velocityX = 0
      ..velocityY = 0.01
      ..velocityZ = 0
      ..hasBounced = true;

    expect(simulation.update(), isNull);
    final hit = simulation.drainEvents().firstWhere(
      (event) => event.type == GameplayEventType.botHit,
    );

    expect(hit.side, MatchSide.player);
    expect(hit.botId, simulation.bottomBotAgent.id);
    expect(hit.botShotType, isNotNull);
  });

  test('spectate mode rejects player swing and dash controls', () {
    final simulation = GameSimulation(gameMode: GameMode.botVsBot);
    simulation.playerVelocityX = 0.04;
    simulation.playerVelocityY = -0.03;
    final beforeX = simulation.playerVelocityX;
    final beforeY = simulation.playerVelocityY;

    expect(simulation.swing(), SwingResult.missed);
    simulation.dashPlayer();

    expect(simulation.rallyLength, 0);
    expect(simulation.playerVelocityX, beforeX);
    expect(simulation.playerVelocityY, beforeY);
  });

  test('low receiving contact selects a net-clearing safe return', () {
    final receiver = BotAgent(
      id: 'receiver',
      side: BotCourtSide.bottom,
      difficulty: BotDifficulty.normal,
      personality: const BotPersonality(
        name: 'Aggressive receiver',
        aggressionAdjustment: 0.30,
      ),
      randomSeed: 3,
    );
    const perception = BotPerception(
      ballX: 0,
      ballY: 0.65,
      ballZ: 0.01,
      ballVelocityX: 0,
      ballVelocityY: 0.01,
      ballVelocityZ: 0,
      ballHasBounced: true,
      opponentX: 0,
      gravity: GameSimulation.gravity,
    );

    final shot = receiver.chooseShot(perception);
    final ticksToNet = perception.ballY / shot.velocityY.abs();
    final heightAtNet =
        perception.ballZ +
        shot.lift * ticksToNet -
        0.5 * perception.gravity * ticksToNet * ticksToNet;

    expect(shot.type, BotShotType.safeReturn);
    expect(shot.velocityY, lessThan(0));
    expect(heightAtNet, greaterThan(PickleballRules.netHeight + 0.04));
  });

  test('difficulty aggression influences the default bot shot plan', () {
    final easy = GameSimulation(botDifficulty: BotDifficulty.easy);
    final hard = GameSimulation(botDifficulty: BotDifficulty.hard);
    easy.ball.z = 0.2;
    hard.ball.z = 0.2;

    expect(easy.chooseBotShot().type, BotShotType.safeReturn);
    expect(hard.chooseBotShot().type, BotShotType.drive);
  });

  test('resetting a rally resets the rally rule state', () {
    final simulation = GameSimulation();
    simulation.resetRally(servingSide: MatchSide.bot);
    simulation.triggerServe();
    expect(simulation.rallyPhase, RallyPhase.serveInFlight);

    simulation.resetRally(servingSide: MatchSide.player);
    expect(simulation.rallyPhase, RallyPhase.waitingForServe);
    expect(simulation.rallyLength, 0);
    expect(simulation.ball.hasBounced, isFalse);
  });

  test('serve box excludes the kitchen line but includes outer lines', () {
    expect(
      PickleballRules.isServeInCorrectBox(
        x: -0.2,
        y: -PickleballRules.kitchenDepth,
        playerServing: true,
        serveFromLeft: false,
      ),
      isFalse,
    );
    expect(
      PickleballRules.isServeInCorrectBox(
        x: -PickleballRules.courtWidth,
        y: -PickleballRules.courtLength,
        playerServing: true,
        serveFromLeft: false,
      ),
      isTrue,
    );
  });

  test('serve first bounce faults when it misses the diagonal service box', () {
    final simulation = GameSimulation();
    simulation.resetRally(servingSide: MatchSide.player, serverScore: 0);
    simulation.triggerServe();

    simulation.ball
      ..x = 0.25
      ..y = -0.65
      ..z = -0.001
      ..velocityX = 0
      ..velocityY = -0.001
      ..velocityZ = -0.01
      ..hasBounced = false;

    expect(simulation.update(), RallyEnd.playerFault);
    expect(simulation.rallyPhase, RallyPhase.deadBall);
  });

  test('servers always start opposite their diagonal serve target', () {
    final simulation = GameSimulation(gameMode: GameMode.botVsBot);

    simulation.resetRally(servingSide: MatchSide.player, serverScore: 0);
    expect(simulation.playerX, greaterThan(0));
    expect(simulation.getPlayerServeTrajectory().targetX, lessThan(0));

    simulation.resetRally(servingSide: MatchSide.player, serverScore: 1);
    expect(simulation.playerX, lessThan(0));
    expect(simulation.getPlayerServeTrajectory().targetX, greaterThan(0));

    simulation.resetRally(servingSide: MatchSide.bot, serverScore: 0);
    expect(simulation.botX, greaterThan(0));
    simulation.triggerServe();
    final botLandingX = simulation.botX + 0.08 + simulation.ball.velocityX * 52;
    expect(botLandingX, lessThan(0));

    simulation.resetRally(servingSide: MatchSide.bot, serverScore: 1);
    expect(simulation.botX, lessThan(0));
    simulation.triggerServe();
    final alternateBotLandingX =
        simulation.botX + 0.08 + simulation.ball.velocityX * 52;
    expect(alternateBotLandingX, greaterThan(0));
  });

  test('normal rally first bounce faults when it lands outside court', () {
    final simulation = GameSimulation();
    simulation
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..lastHitByPlayer = true;
    simulation.ball
      ..x = PickleballRules.courtWidth + 0.05
      ..y = -0.7
      ..z = -0.001
      ..velocityX = 0
      ..velocityY = -0.001
      ..velocityZ = -0.01
      ..hasBounced = false;

    expect(simulation.update(), RallyEnd.playerFault);
    expect(simulation.rallyPhase, RallyPhase.deadBall);
  });

  test('second bounce faults the player on the player side', () {
    final simulation = GameSimulation();
    simulation
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..lastHitByPlayer = false;
    simulation.ball
      ..x = 0
      ..y = 0.6
      ..z = -0.001
      ..velocityX = 0
      ..velocityY = 0.001
      ..velocityZ = -0.01
      ..hasBounced = true;

    expect(simulation.update(), RallyEnd.playerFault);
    expect(simulation.rallyPhase, RallyPhase.deadBall);
  });

  test('player shot uses two-axis directional aiming', () {
    final leftDeep = GameSimulation()
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..playerX = 0
      ..playerY = 0.75;
    leftDeep.ball
      ..x = 0
      ..y = 0.6
      ..z = 0.2
      ..velocityY = 0.01
      ..hasBounced = true;

    expect(leftDeep.swing(joystickX: -1, joystickY: -1), SwingResult.hit);
    expect(leftDeep.ball.velocityX, lessThan(0));

    final rightShort = GameSimulation()
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..playerX = 0
      ..playerY = 0.75;
    rightShort.ball
      ..x = 0
      ..y = 0.6
      ..z = 0.2
      ..velocityY = 0.01
      ..hasBounced = true;

    expect(rightShort.swing(joystickX: 1, joystickY: 1), SwingResult.hit);
    expect(rightShort.ball.velocityX, greaterThan(0));
    expect(
      rightShort.ball.velocityY.abs(),
      closeTo(leftDeep.ball.velocityY.abs(), 0.0001),
    );
  });

  test('centered contact produces perfect shot quality', () {
    final simulation = GameSimulation()
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..playerX = 0
      ..playerY = 0.75;
    simulation.ball
      ..x = 0
      ..y = 0.75
      ..z = 0.2
      ..velocityY = 0.01
      ..hasBounced = true;

    expect(simulation.swing(), SwingResult.hit);
    final hit = simulation.drainEvents().firstWhere(
      (event) => event.type == GameplayEventType.playerHit,
    );
    expect(hit.shotQuality, ShotQuality.perfect);
    expect(hit.isSmash, isFalse);
  });

  test('high contact produces a smash event', () {
    final simulation = GameSimulation()
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..playerX = 0
      ..playerY = 0.75;
    simulation.ball
      ..x = 0
      ..y = 0.75
      ..z = 0.45
      ..velocityY = 0.01
      ..hasBounced = true;

    expect(simulation.swing(), SwingResult.hit);
    final hit = simulation.drainEvents().firstWhere(
      (event) => event.type == GameplayEventType.playerHit,
    );
    expect(hit.isSmash, isTrue);
    expect(simulation.ball.velocityY.abs(), greaterThan(0.03));
  });

  test('simulation emits player hit events', () {
    final simulation = GameSimulation();
    simulation
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..playerX = 0
      ..playerY = 0.75;
    simulation.ball
      ..x = 0
      ..y = 0.6
      ..z = 0.2
      ..velocityY = 0.01
      ..hasBounced = true;

    expect(simulation.swing(), SwingResult.hit);
    final events = simulation.drainEvents();

    expect(
      events.any((event) => event.type == GameplayEventType.playerHit),
      isTrue,
    );
    expect(simulation.drainEvents(), isEmpty);
  });

  test('rally faults emit their cause and rally-end events', () {
    final simulation = GameSimulation();
    simulation
      ..playPhase = MatchPlayPhase.inRally
      ..rallyPhase = RallyPhase.openRally
      ..lastHitByPlayer = true;
    simulation.ball
      ..x = PickleballRules.courtWidth + 0.05
      ..y = -0.7
      ..z = -0.001
      ..velocityX = 0
      ..velocityY = -0.001
      ..velocityZ = -0.01
      ..hasBounced = false;

    expect(simulation.update(), RallyEnd.playerFault);
    final events = simulation.drainEvents();

    expect(
      events.any((event) => event.type == GameplayEventType.outOfBounds),
      isTrue,
    );
    expect(
      events.any((event) => event.type == GameplayEventType.rallyEnd),
      isTrue,
    );
  });

  test('ball speed is reported in miles per hour', () {
    final simulation = GameSimulation();
    simulation.ball
      ..velocityX = 0
      ..velocityY = 0.025
      ..velocityZ = 0;

    // 0.025 world units/tick * 22 ft/unit * 40 ticks/sec = 22 ft/sec.
    expect(simulation.ballSpeed, closeTo(15.0, 0.1));
  });

  test('match state handles side-outs and win-by-two scoring', () {
    final match = MatchState(servingSide: MatchSide.player);
    match.start();

    // Player faults -> bot wins rally -> side-out (bot serves, 0-0)
    match.resolveRally(rallyWinner: MatchSide.bot);
    expect(match.playerScore, 0);
    expect(match.botScore, 0);
    expect(match.servingSide, MatchSide.bot);

    // Player faults again -> bot wins rally -> bot was serving, gets point (0-1)
    match.resolveRally(rallyWinner: MatchSide.bot);
    expect(match.botScore, 1);

    match.playerScore = 10;
    match.botScore = 10;
    match.servingSide = MatchSide.player;

    // Player wins rally while serving -> 11-10 (not win by 2 yet)
    match.resolveRally(rallyWinner: MatchSide.player);
    expect(match.isComplete, isFalse);

    // Player wins rally again while serving -> 12-10 (game over)
    match.resolveRally(rallyWinner: MatchSide.player);
    expect(match.isComplete, isTrue);
  });

  test('Flame adapter advances simulation on a fixed step', () {
    final simulation = GameSimulation();
    final game = PickleballFlameGame(simulation: simulation);
    final initialY = simulation.ball.y;
    game.start();

    game.update(PickleballFlameGame.fixedStep);

    expect(simulation.ball.y, greaterThan(initialY));
  });

  testWidgets('renders the pickleball game controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickleballGame()));
    await tester.pump();

    expect(find.text('CPU: 0'), findsOneWidget);
    expect(find.text('YOU: 0'), findsOneWidget);
    expect(find.text('TOSS'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is GameWidget),
      findsOneWidget,
    );

    // Tap 1: Toss the ball
    await tester.tap(find.text('TOSS'));
    await tester.pump();
    expect(find.text('STRIKE!'), findsOneWidget);

    // Wait for the ball to rise into the sweet spot (~650ms)
    await tester.pump(const Duration(milliseconds: 650));

    // Tap 2: Strike the serve at the sweet spot
    await tester.tap(find.text('STRIKE!'));
    await tester.pump();
    expect(find.text('HIT'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('main menu passes the selected CPU difficulty to the game', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

    await tester.tap(find.text('START A MATCH'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Player vs Bot'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SELECT CPU DIFFICULTY'), findsOneWidget);
    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final game = tester.widget<PickleballGame>(
      find.byType(PickleballGame, skipOffstage: false),
    );
    expect(game.botDifficulty, BotDifficulty.hard);

    // Dispose the animated menu, then let its already-scheduled callback
    // observe that it is no longer mounted.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  test('practice facility initializes in open rally and feeds drills', () {
    final simulation = GameSimulation(
      gameMode: GameMode.freeRoamPractice,
      mapType: MapType.practiceFacility,
    );
    expect(simulation.playPhase, MatchPlayPhase.inRally);
    expect(simulation.rallyPhase, RallyPhase.openRally);

    simulation.launchBallMachine(drill: PracticeDrill.dinks);
    expect(simulation.ball.y, lessThan(0));
    expect(simulation.ball.velocityY, greaterThan(0));

    simulation.launchBallMachine(drill: PracticeDrill.drives);
    expect(simulation.ball.velocityY, greaterThan(0.025));

    simulation.launchBallMachine(drill: PracticeDrill.lobs);
    expect(simulation.ball.velocityZ, greaterThan(0.025));
  });

  test('practice target hit awards points and increments streak', () {
    final simulation = GameSimulation(
      gameMode: GameMode.freeRoamPractice,
      mapType: MapType.practiceFacility,
    );
    final initialScore = simulation.practiceScore;
    final initialTarget = simulation.activeTarget;

    // Simulate player returning the ball directly into the active target
    simulation.lastHitByPlayer = true;
    simulation.ball
      ..x = initialTarget.x
      ..y = initialTarget.y
      ..z = 0.01
      ..velocityX = 0
      ..velocityY = -0.01
      ..velocityZ = -0.01
      ..hasBounced = false;

    simulation.update();

    expect(simulation.practiceStreak, 1);
    expect(simulation.practiceScore, greaterThan(initialScore));
    expect(simulation.practiceTargetHits, 1);
  });

  test(
    'cloth net collision absorbs energy, rebounds gently, and sets ripple',
    () {
      final simulation = GameSimulation(gameMode: GameMode.playerVsBot);
      simulation.resetRally(servingSide: MatchSide.player);
      simulation.playPhase = MatchPlayPhase.inRally;
      simulation.rallyPhase = RallyPhase.openRally;

      var netHitCallbackFired = false;
      simulation.onNetHit = () => netHitCallbackFired = true;

      // Ball traveling from player side (y > 0) towards net (velocityY < 0)
      // Low shot that will collide into the net below regulation net height
      simulation.ball
        ..x = 0.05
        ..y = 0.02
        ..z =
            0.08 // Below netHeight (0.1364)
        ..velocityX = 0.01
        ..velocityY = -0.03
        ..velocityZ = -0.002
        ..hasBounced = false;

      final rallyEnd = simulation.update();

      expect(rallyEnd, RallyEnd.playerFault);
      expect(netHitCallbackFired, isTrue);
      expect(simulation.ball.y, greaterThan(0)); // Stayed on player side
      expect(simulation.ball.velocityY, greaterThan(0)); // Reversed gently
      expect(
        simulation.ball.velocityY,
        lessThan(0.01),
      ); // Heavily damped (~88% absorbed)
      expect(simulation.netImpactIntensity, greaterThan(0));
      expect(simulation.netImpactDirection, -1.0); // Deflected towards bot

      final events = simulation.drainEvents();
      expect(events.any((e) => e.type == GameplayEventType.netFault), isTrue);
    },
  );

  test('practice mode cloth net collision resets streak and drops softly', () {
    final simulation = GameSimulation(gameMode: GameMode.freeRoamPractice);
    simulation.practiceStreak = 5;
    simulation.lastHitByPlayer = true;

    var netHitCallbackFired = false;
    simulation.onNetHit = () => netHitCallbackFired = true;

    simulation.ball
      ..x = -0.1
      ..y = 0.025
      ..z =
          0.06 // Below netHeight
      ..velocityX = 0.0
      ..velocityY = -0.035
      ..velocityZ = 0.0
      ..hasBounced = false;

    simulation.update();

    expect(simulation.practiceStreak, 0); // Streak reset on net fault
    expect(netHitCallbackFired, isTrue);
    expect(simulation.ball.y, greaterThan(0)); // Kept in front of net
    expect(simulation.ball.velocityY, greaterThan(0)); // Soft rebound
  });

  test('shots above net height clear cleanly without net collision', () {
    final simulation = GameSimulation(gameMode: GameMode.playerVsBot);
    simulation.playPhase = MatchPlayPhase.inRally;
    simulation.rallyPhase = RallyPhase.openRally;

    // Ball traveling from player side towards bot court, safely above net
    simulation.ball
      ..x = 0.0
      ..y = 0.02
      ..z =
          PickleballRules.netHeight +
          0.05 // Safely above net
      ..velocityX = 0.0
      ..velocityY = -0.03
      ..velocityZ = 0.005
      ..hasBounced = false;

    final rallyEnd = simulation.update();

    expect(rallyEnd, isNull); // Clean clearance, no fault
    expect(simulation.ball.y, lessThan(0)); // Crosses over into bot court
    expect(simulation.netImpactIntensity, 0.0); // No net deflection
  });

  testWidgets('phone landscape layouts do not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('START A MATCH'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Player vs Bot'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('SELECT CPU DIFFICULTY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: PickleballGame()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'GamePauseOverlay renders without overflow on compact landscape viewports',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 260);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamePauseOverlay(
              onResume: () {},
              onRestart: () {},
              onQuit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('QUIT'), findsOneWidget);
    },
  );

  testWidgets(
    'MatchCompleteOverlay renders without overflow on compact landscape viewports',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 260);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchCompleteOverlay(
              playerScore: 11,
              botScore: 8,
              onPlayAgain: () {},
              onBackToMenu: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('🏆 VICTORY'), findsOneWidget);
      expect(find.text('11 - 8'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('BACK TO MENU'), findsOneWidget);
    },
  );

  testWidgets(
    'PaddleShopScreen renders without overflow on compact landscape viewports',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 280);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PaddleShopScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('PADDLE ARSENAL'), findsOneWidget);
    },
  );

  test('ServeRhythmController sweet spot timing and do-over mechanics', () {
    final controller = ServeRhythmController();
    expect(controller.phase, ServeRhythmPhase.idle);
    expect(controller.ballTossZ, 0.0);

    controller.startToss();
    expect(controller.phase, ServeRhythmPhase.tossing);
    expect(controller.progress, 0.0);

    // Progress to halfway
    controller.progress = 0.5;
    expect(controller.ballTossZ, greaterThan(0.25));

    // Progress to perfect sweet spot (0.65)
    controller.progress = ServeRhythmController.sweetSpot;
    final perfectResult = controller.strike();
    expect(perfectResult.quality, ShotQuality.perfect);
    expect(perfectResult.powerMultiplier, 1.25);
    expect(perfectResult.isWhiff, isFalse);
    expect(perfectResult.feedbackMessage, 'PERFECT SERVE!');
    expect(controller.phase, ServeRhythmPhase.complete);

    // Test whiff and do-over
    controller.startToss();
    controller.progress = 1.0;
    final whiffResult = controller.strike();
    expect(whiffResult.isWhiff, isTrue);
    expect(whiffResult.feedbackMessage, 'DO OVER!');

    // Test timeout whiff
    controller.startToss();
    final timedOut = controller.update(1.2);
    expect(timedOut, isTrue);
    expect(controller.phase, ServeRhythmPhase.whiffed);

    controller.reset();
    expect(controller.phase, ServeRhythmPhase.idle);
  });

  test('GameSimulation two-tap serve rhythm with toss and strike', () {
    final simulation = GameSimulation();
    simulation.resetRally(servingSide: MatchSide.player);
    expect(simulation.playPhase, MatchPlayPhase.waitingForServe);
    expect(simulation.serveRhythm.phase, ServeRhythmPhase.idle);

    // Tap 1: Start toss
    final tossResult = simulation.swing();
    expect(tossResult, SwingResult.missed);
    expect(simulation.serveRhythm.phase, ServeRhythmPhase.tossing);
    expect(simulation.playPhase, MatchPlayPhase.waitingForServe);

    // Simulate toss in flight
    simulation.serveRhythm.progress = ServeRhythmController.sweetSpot;

    // Tap 2: Strike at sweet spot
    final strikeResult = simulation.swing();
    expect(strikeResult, SwingResult.hit);
    expect(simulation.playPhase, MatchPlayPhase.inRally);
    expect(simulation.rallyPhase, RallyPhase.serveInFlight);
    expect(simulation.lastHitByPlayer, isTrue);
    expect(simulation.lastServeTiming?.quality, ShotQuality.perfect);
  });

  test('GameSimulation penalty-free serve do-over on whiff', () {
    final simulation = GameSimulation();
    simulation.resetRally(servingSide: MatchSide.player);

    var whiffCallbackFired = false;
    simulation.onServeWhiff = () => whiffCallbackFired = true;

    // Tap 1: Toss
    simulation.swing();
    expect(simulation.serveRhythm.phase, ServeRhythmPhase.tossing);

    // Let the ball drop without swinging (simulate elapsed time)
    for (int i = 0; i < 50; i++) {
      simulation.update();
    }

    // Must reset to waiting for serve with no score change
    expect(whiffCallbackFired, isTrue);
    expect(simulation.playPhase, MatchPlayPhase.waitingForServe);
    expect(simulation.serveRhythm.phase, ServeRhythmPhase.idle);
    expect(simulation.currentServerScore, 0);
  });

  testWidgets('ServeRhythmMeter renders correctly during idle and active toss',
      (WidgetTester tester) async {
    final controller = ServeRhythmController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ServeRhythmMeter(controller: controller),
          ),
        ),
      ),
    );
    expect(find.text('SERVE METER'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('PERFECT'), findsOneWidget);

    controller.startToss();
    controller.progress = 0.65;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ServeRhythmMeter(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('HIT SWEET SPOT!'), findsOneWidget);
    expect(find.text('TIMING'), findsOneWidget);
  });

  test('USAP court net height curvature matches regulation standards', () {
    // USAP Rule 2.C.2: Net is 34" at center, 36" at posts
    expect(PickleballRules.netHeightCenter, lessThan(PickleballRules.netHeightPosts));
    expect(PickleballRules.netHeightAtX(0.0), closeTo(PickleballRules.netHeightCenter, 0.0001));
    expect(
      PickleballRules.netHeightAtX(PickleballRules.courtWidth),
      closeTo(PickleballRules.netHeightPosts, 0.0001),
    );
    // Mid-court net height should be strictly between center and post
    final midNet = PickleballRules.netHeightAtX(PickleballRules.courtWidth * 0.5);
    expect(midNet, greaterThan(PickleballRules.netHeightCenter));
    expect(midNet, lessThan(PickleballRules.netHeightPosts));
  });

  test('USAP rulebook data contains comprehensive official citations and glossary', () {
    expect(UsapRulebookData.rules.isNotEmpty, isTrue);
    expect(UsapRulebookData.glossary.isNotEmpty, isTrue);

    // Verify critical rules exist with citations
    final ruleNumbers = UsapRulebookData.rules.map((r) => r.ruleNumber).toList();
    expect(ruleNumbers, contains('Rule 2.A'));
    expect(ruleNumbers, contains('Rule 2.C'));
    expect(ruleNumbers, contains('Rule 4.A'));
    expect(ruleNumbers, contains('Rule 4.N'));
    expect(ruleNumbers, contains('Rule 9.B'));
    expect(ruleNumbers, contains('Rule 12.A'));

    // Check glossary terms
    final terms = UsapRulebookData.glossary.map((g) => g.term).toList();
    expect(terms, contains('Kitchen (NVZ)'));
    expect(terms, contains('Two-Bounce Rule'));
    expect(terms, contains('Dink'));
    expect(terms, contains('Erne'));
  });

  testWidgets('RulebookScreen renders, filters categories, and performs live search',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RulebookScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and initial elements
    expect(find.text('OFFICIAL USAP RULEBOOK'), findsOneWidget);
    expect(find.text('USAP REGULATION COURT'), findsOneWidget);
    expect(find.text('All Rules'), findsOneWidget);
    expect(find.text('Court Dimensions'), findsOneWidget);

    // Filter by Serving category
    await tester.tap(find.text('Serving (Rule 4)'));
    await tester.pumpAndSettle();
    expect(find.text('Service Execution & Motion'), findsOneWidget);
    expect(find.text('Diagonal Crosscourt Requirement'), findsOneWidget);

    // Filter by Glossary
    await tester.tap(find.text('Glossary'));
    await tester.pumpAndSettle();
    expect(find.text('Dink'), findsOneWidget);
    expect(find.text('Kitchen (NVZ)'), findsOneWidget);

    // Live search query test
    await tester.enterText(find.byType(TextField), 'Erne');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(GlossaryCardWidget, 'Erne'), findsOneWidget);
  });
}


