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
import 'package:pickle_ball_game/screens/main_menu_screen.dart';

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
      lessThan(simulation.camera.project(x: 0, y: GameSimulation.courtLength).scale),
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
      ..x = 0.34
      ..y = 0.44
      ..z = 0.84;
    expect(simulation.canPlayerHitBall(), isTrue);

    simulation.ball.x = 0.36;
    expect(simulation.canPlayerHitBall(), isFalse);
    simulation.ball
      ..x = 0
      ..y = 0.42;
    expect(simulation.canPlayerHitBall(), isFalse);
    simulation.ball
      ..y = 0.75
      ..z = 0.86;
    expect(simulation.canPlayerHitBall(), isFalse);

    simulation.botX = 0;
    simulation.botY = -0.75;
    simulation.ball
      ..x = 0.34
      ..y = -0.44
      ..z = 0.84;
    expect(simulation.canBotHitBall(), isTrue);

    simulation.ball.y = -0.42;
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

  test('bot selects safe, drive, and smash plans from ball height and aggression', () {
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
  });

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
    final hit = simulation
        .drainEvents()
        .firstWhere((event) => event.type == GameplayEventType.botHit);

    expect(hit.side, MatchSide.player);
    expect(hit.botId, simulation.bottomBotAgent.id);
    expect(hit.botShotType, isNotNull);
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

    expect(
      leftDeep.swing(joystickX: -1, joystickY: -1),
      SwingResult.hit,
    );
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

    expect(
      rightShort.swing(joystickX: 1, joystickY: 1),
      SwingResult.hit,
    );
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
    final hit = simulation
        .drainEvents()
        .firstWhere((event) => event.type == GameplayEventType.playerHit);
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
    final hit = simulation
        .drainEvents()
        .firstWhere((event) => event.type == GameplayEventType.playerHit);
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
    expect(find.text('SERVE'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is GameWidget),
      findsOneWidget,
    );

    await tester.tap(find.text('SERVE'));
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
}
