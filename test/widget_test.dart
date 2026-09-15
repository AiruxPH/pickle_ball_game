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
    final projectedCenter = simulation.projection.project(x: 0, y: 0);
    expect(projectedCenter.x, 0);
    expect(projectedCenter.y, 0);
    expect(
      simulation.projection.depthScaleAt(-GameSimulation.courtLength),
      lessThan(simulation.projection.depthScaleAt(GameSimulation.courtLength)),
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

    expect(find.text('CPU: 0'), findsOneWidget);
    expect(find.text('YOU: 0'), findsOneWidget);
    expect(find.text('TAP TO SERVE'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is GameWidget),
      findsOneWidget,
    );

    await tester.tap(find.text('TAP TO SERVE'));
    await tester.pump();

    expect(find.text('HIT'), findsOneWidget);
  });
}
