// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pickle_ball_game/main.dart';
import 'package:pickle_ball_game/pickleball_rules.dart';

void main() {
  test('court and match rules use shared boundaries', () {
    expect(PickleballRules.isInsideCourt(0, 0), isTrue);
    expect(PickleballRules.isInsideCourt(0.83, 0), isFalse);
    expect(PickleballRules.isWinningScore(11, 9), isTrue);
    expect(PickleballRules.isWinningScore(11, 10), isFalse);
  });

  testWidgets('renders the pickleball game controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickleballGame()));

    expect(find.text('CPU: 0'), findsOneWidget);
    expect(find.text('YOU: 0'), findsOneWidget);
    expect(find.text('TAP TO SERVE'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.tap(find.text('TAP TO SERVE'));
    await tester.pump();

    expect(find.text('HIT'), findsOneWidget);
  });
}
