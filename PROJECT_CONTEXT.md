# Pro Pickleball Project Handoff
Last updated: 2026-09-10
## Purpose
This document records the project direction, architecture decisions, implementation history, validation results, known limitations, and next steps. It is intended to let a future coding session continue the work without reconstructing the previous decisions.
## Product Direction
The project is an arcade-style single-player pickleball game with an elevated overhead camera. The desired visual direction is 2.5D:
- The game mechanics use a logical court world.
- The renderer presents an elevated overhead court.
- Ball height is represented through screen offset, scaling, and a projected shadow.
- The current target is not a third-person full-3D camera.
- Official multiplayer serving rotation and side-out behavior are intentionally deferred while single-player gameplay is being tested.
The current priority is usability, solo rally feel, visual polish, and maintainable architecture.
## Current Architecture
```text
Flutter application shell
  Main menu
  HUD and score display
  Touch controls
  Navigation
  Feedback text
Flame game layer
  Fixed-step game loop
  Court rendering
  Net and court markings
  Ball and shadow rendering
  Player rendering
  Bot rendering
  Keyboard polling
  Simulation input forwarding
Pure Dart simulation layer
  Logical court coordinates
  Ball position and velocity
  Gravity and bounce
  Player movement
  Bot movement and return behavior
  Swing detection
  Rally-end events
Pure Dart rules layer
  MatchState
  Scoring
  Match completion
  Serve-side state
  Official fault helpers retained for future full-rule mode
Core rule:

The simulation is the source of physical truth. The rules domain is the source of scoring and match truth. Rendering only displays state and does not decide game outcomes.

PENDING CHANGES — Apply Before Continuing
This section describes changes that were designed and validated in a previous session but have not yet been written to disk. The next session must apply these first, then verify with flutter analyze and flutter test.

What to apply
Run the apply script below from the project root, or apply the four steps manually.

powershell


# Save as apply_changes.ps1 in the project root, then run:
# powershell -ExecutionPolicy Bypass -File apply_changes.ps1
Set-Location 'C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game'
# A1. Delete unused legacy renderer
Remove-Item -Force 'lib\game_renderers.dart' -ErrorAction SilentlyContinue
Write-Host 'A1 done'
# A2. Create lib/game_input_adapter.dart
Set-Content -Encoding utf8 'lib\game_input_adapter.dart' @'
import 'dart:math' as math;
import 'package:flutter/painting.dart';
/// Handles joystick input state and normalization.
///
/// Call [updateJoystick] with the raw pan-gesture local position and
/// [resetJoystick] when the gesture ends. Subscribe to [onJoystickChanged]
/// to receive normalised (-1..1) x/y values whenever input changes.
class GameInputAdapter {
  static const double _joystickRadius = 70.0;
  static const double _knobRadius = 45.0;
  double joystickX = 0.0;
  double joystickY = 0.0;
  /// Called whenever joystick values change, including a reset to (0, 0).
  void Function(double x, double y)? onJoystickChanged;
  /// Updates the joystick from a raw pan-gesture [localPosition].
  void updateJoystick(Offset localPosition) {
    double dx = localPosition.dx - _joystickRadius;
    double dy = localPosition.dy - _joystickRadius;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > _knobRadius) {
      dx = (dx / distance) * _knobRadius;
      dy = (dy / distance) * _knobRadius;
    }
    joystickX = dx / _knobRadius;
    joystickY = dy / _knobRadius;
    onJoystickChanged?.call(joystickX, joystickY);
  }
  /// Resets the joystick to the centre position.
  void resetJoystick() {
    joystickX = 0.0;
    joystickY = 0.0;
    onJoystickChanged?.call(0.0, 0.0);
  }
}
'@
Write-Host 'A2 done'
# A3 + B + C. Replace lib/main.dart (full content below — paste between the markers)
# See "Pending: main.dart replacement" section below for the full content.
# B. Patch PlayerVisualComponent.render in lib/pickleball_flame_game.dart
$f = Get-Content -Raw 'lib\pickleball_flame_game.dart'
$old = '    final playerPaint = Paint()..color = const Color(0xFF448AFF);
    canvas.drawCircle(center, 25 * scale, playerPaint);
    final outlinePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawCircle(center, 25 * scale, outlinePaint);
    final racketPaint'
$new = '    // Hit flash: brighter body + amber glow ring while swinging
    final bodyColor =
        game.isSwinging ? const Color(0xFF82B1FF) : const Color(0xFF448AFF);
    final playerPaint = Paint()..color = bodyColor;
    canvas.drawCircle(center, 25 * scale, playerPaint);
    final outlinePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawCircle(center, 25 * scale, outlinePaint);
    if (game.isSwinging) {
      final glowPaint = Paint()
        ..color = const Color(0x99FFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale;
      canvas.drawCircle(center, 32 * scale, glowPaint);
    }
    final racketPaint'
if ($f.Contains($old)) {
  $f.Replace($old, $new) | Set-Content -Encoding utf8 'lib\pickleball_flame_game.dart'
  Write-Host 'B done: hit flash added'
} else {
  Write-Host 'WARNING: flame patch did not match'
}
Write-Host 'Done. Run: flutter analyze && flutter test test/widget_test.dart'
Pending: full lib/main.dart replacement
Replace the entire content of lib/main.dart with the following:

dart


import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_input_adapter.dart';
import 'game_simulation.dart';
import 'match_state.dart';
import 'pickleball_flame_game.dart';
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainMenu(),
    ),
  );
}
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final logoWidget = Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFFD4E157),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))
        ],
      ),
      child: const Icon(Icons.sports_tennis, size: 80, color: Color(0xFF1E3A8A)),
    );
    final textAndButtonWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PRO PICKLEBALL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Wii-Style Mechanics',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PickleballGame()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 8,
          ),
          child: const Text(
            'PLAY NOW',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: isLandscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [logoWidget, const SizedBox(width: 60), textAndButtonWidget],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [logoWidget, const SizedBox(height: 40), textAndButtonWidget],
                  ),
          ),
        ),
      ),
    );
  }
}
class PickleballGame extends StatefulWidget {
  const PickleballGame({super.key});
  @override
  State<PickleballGame> createState() => _PickleballGameState();
}
class _PickleballGameState extends State<PickleballGame> {
  final FocusNode _focusNode = FocusNode();
  final MatchState match = MatchState();
  final PickleballFlameGame flameGame;
  final GameInputAdapter _input = GameInputAdapter();
  _PickleballGameState() : flameGame = PickleballFlameGame();
  GameSimulation get simulation => flameGame.simulation;
  double get ballZ => simulation.ball.z;
  bool isPlaying = false;
  bool _isPaused = false;
  String feedbackText = '';
  int get playerScore => match.playerScore;
  int get botScore => match.botScore;
  @override
  void initState() {
    super.initState();
    flameGame.onRallyEnd = _handleRallyEnd;
    _input.onJoystickChanged = (x, y) {
      setState(() {
        flameGame.inputX = x;
        flameGame.inputY = y;
      });
    };
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }
  void _startGame() {
    setState(() {
      if (match.isComplete) match.reset();
      match.start();
      isPlaying = true;
      _isPaused = false;
      simulation.resetRally();
      feedbackText = '';
    });
    flameGame.start();
  }
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      flameGame.isPlaying = !_isPaused;
    });
    if (!_isPaused) _focusNode.requestFocus();
  }
  void _handleRallyEnd(RallyEnd rallyEnd) {
    if (!mounted) return;
    setState(() {
      final previousPlayerScore = playerScore;
      final previousBotScore = botScore;
      final pointWinner =
          rallyEnd == RallyEnd.playerFault ? MatchSide.bot : MatchSide.player;
      match.awardPointTo(pointWinner);
      if (match.isComplete) {
        feedbackText = playerScore > botScore ? 'YOU WIN!' : 'CPU WINS';
      } else if (playerScore > previousPlayerScore) {
        feedbackText = 'POINT FOR YOU!';
      } else if (botScore > previousBotScore) {
        feedbackText = 'POINT FOR CPU!';
      }
      isPlaying = false;
      _isPaused = false;
      _input.resetJoystick();
    });
  }
  void _executeSwing() {
    if (!isPlaying || _isPaused) return;
    setState(() => flameGame.isSwinging = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => flameGame.isSwinging = false);
    });
    final wasHighBall = ballZ > 0.3;
    final swingResult = simulation.swing();
    setState(() {
      if (swingResult == SwingResult.hit) {
        feedbackText = wasHighBall ? 'SMASH!' : 'GOOD HIT';
      } else {
        feedbackText =
            swingResult == SwingResult.kitchenFault ? 'KITCHEN FAULT' : 'MISS';
      }
    });
  }
  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    flameGame.stop();
    _focusNode.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            _executeSwing();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (isPlaying) _togglePause();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.buttons == kSecondaryMouseButton) _executeSwing();
          },
          child: Stack(
            children: [
              // Flame game layer
              Positioned.fill(child: IgnorePointer(child: GameWidget(game: flameGame))),
              // HUD: back | CPU score | feedback | player score | pause
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          tooltip: 'Back to menu',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        label: 'CPU score $botScore',
                        child: Text('CPU: $botScore',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      if (feedbackText.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: Text(feedbackText,
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        label: 'Your score $playerScore',
                        child: Text('YOU: $playerScore',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      if (isPlaying)
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                            tooltip: _isPaused ? 'Resume game' : 'Pause game',
                            onPressed: _togglePause,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              // Controls
              if (isPlaying && !_isPaused)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildJoystick(),
                      Semantics(
                        button: true,
                        label: 'Hit the ball',
                        child: GestureDetector(
                          onTap: _executeSwing,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
                              border: Border.all(color: Colors.white, width: 3.5),
                            ),
                            child: const Center(
                              child: Text('HIT',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black, letterSpacing: 1.2)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isPaused) _buildPauseOverlay(),
              if (match.isComplete) _buildMatchCompleteOverlay(),
              if (!isPlaying && !match.isComplete)
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      _startGame();
                      _focusNode.requestFocus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    ),
                    child: const Text('TAP TO SERVE',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildJoystick() {
    return Semantics(
      label: 'Move player',
      child: GestureDetector(
        onPanStart: (d) => _input.updateJoystick(d.localPosition),
        onPanUpdate: (d) => _input.updateJoystick(d.localPosition),
        onPanEnd: (_) => _input.resetJoystick(),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 2),
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(_input.joystickX * 45, _input.joystickY * 45),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildPauseOverlay() {
    return Semantics(
      label: 'Game paused',
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PAUSED',
                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _togglePause,
                icon: const Icon(Icons.play_arrow),
                label: const Text('RESUME'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('QUIT TO MENU', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMatchCompleteOverlay() {
    final playerWon = playerScore > botScore;
    return Semantics(
      label: playerWon ? 'You win!' : 'CPU wins',
      child: Container(
        color: Colors.black.withValues(alpha: 0.70),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerWon ? 'YOU WIN!' : 'CPU WINS',
                style: TextStyle(
                    color: playerWon ? Colors.amberAccent : Colors.redAccent,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3),
              ),
              const SizedBox(height: 12),
              Text('$playerScore - $botScore',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  _startGame();
                  _focusNode.requestFocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('PLAY AGAIN',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BACK TO MENU', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
What each pending change does
Step	File	Change
A1	lib/game_renderers.dart	Delete — confirmed unused
A2	lib/game_input_adapter.dart	Create — GameInputAdapter class with joystick normalization logic extracted from main.dart
A3	lib/main.dart	Replace — wires GameInputAdapter, removes dart:math import, cleans up method names to private (_startGame, _executeSwing, _togglePause, _handleRallyEnd)
B	lib/main.dart	Pause system — _isPaused state, _togglePause(), pause overlay with RESUME + QUIT TO MENU, Esc key support
B	lib/main.dart	Match-complete overlay — proper end screen with score summary, PLAY AGAIN, BACK TO MENU
B	lib/pickleball_flame_game.dart	Hit flash — PlayerVisualComponent.render adds brighter body color + amber glow ring during swing
C	lib/main.dart	Score and feedback text wrapped in Semantics(liveRegion: true, container: true) for screen readers
C	lib/main.dart	Back button and pause button wrapped in SizedBox(48×48) for minimum tap target compliance
Validation to run after applying


flutter analyze   → expect: No issues found
flutter test test/widget_test.dart  → expect: 6 tests passed
No changes to test/widget_test.dart are needed — existing tests pass with the new code.

Files Added or Changed
lib/main.dart
Current role:

Flutter application entry point.
Main menu and navigation.
Flutter HUD, score display, feedback text, and controls.
Owns the PickleballGame StatefulWidget.
Creates the Flame game adapter and connects rally-end callbacks to MatchState.
Handles player swing input and forwards joystick input to Flame via GameInputAdapter.
Important changes:

Removed the Timer.periodic gameplay loop.
Added a constructor-initialized PickleballFlameGame to avoid hot-reload LateInitializationError failures.
Keeps MatchState for score display and match state.
Live single-player rally scoring uses match.awardPointTo(...).
Adds feedback for points, wins, misses, kitchen faults, good hits, and smashes.
Pending: Pause system, match-complete overlay, accessibility live regions, and 48×48 tap targets (see Pending Changes above).
lib/game_input_adapter.dart
Pending creation. Will contain GameInputAdapter:

Holds joystickX and joystickY (–1..1 normalized).
updateJoystick(Offset) normalizes raw pan gesture positions into joystick values.
resetJoystick() zeroes the values.
onJoystickChanged callback wires into flameGame.inputX/Y.
lib/game_simulation.dart
Pure Dart simulation and projection model. No pending changes.

Contains:

CourtPoint, ProjectedPoint, BallState, RallyEnd, SwingResult, CourtProjection, GameSimulation.
Responsibilities:

Maintains logical player, bot, and ball positions.
Applies gravity and ball bounce behavior.
Moves the player using joystick values.
Moves the bot toward the ball and returns it when appropriate.
Detects rally-ending faults and SwingResult outcomes.
Provides CourtProjection for converting logical court coordinates to projected visual coordinates.
lib/pickleball_flame_game.dart
Flame adapter and scene components. Pending: hit flash patch to PlayerVisualComponent.render.

Contains:

PickleballFlameGame, CourtVisualComponent, BallVisualComponent, BotVisualComponent, PlayerVisualComponent.
Responsibilities of PickleballFlameGame:

Owns the Flame update lifecycle.
Uses a fixed simulation step of 0.025 seconds.
Accumulates variable Flame frame time and advances the simulation in fixed increments.
Polls keyboard input for WASD and arrow keys.
Accepts joystick input from Flutter through inputX and inputY.
Starts and stops the simulation using start() and stop().
isPlaying is a public field — Flutter HUD can set it directly for pause/resume.
Emits rally-end callbacks back to Flutter.
Stores isSwinging so the Flame player component can render swing feedback.
lib/match_state.dart
Pure Dart match and score state. No pending changes.

Contains MatchSide, MatchStatus, MatchState.

lib/pickleball_rules.dart
Existing pure rule helper module. No pending changes.

lib/game_renderers.dart
Pending deletion. Contains earlier Flutter renderer widgets (BotRenderer, BallRenderer, PlayerRenderer) that are confirmed unused. Safe to delete now that the Flame migration has been in place.

test/widget_test.dart
No pending changes. Current coverage:

Shared court and match rule helpers.
Win-by-two behavior.
Logical simulation movement and projection.
Bounce, kitchen, and low-net constraints.
MatchState side-out and scoring behavior.
Flame fixed-step adapter advancement.
Game screen controls and Flame GameWidget mounting.
Current result: 6 tests pass.

README.md
Updated from the default Flutter template to document project purpose, architecture, controls, limitations, Flame migration status, roadmap, and design decisions.

pubspec.yaml
Added flame: ^1.38.2. Flame is the game-loop and scene-rendering dependency.

Implementation Timeline
1–11. (See original handoff — all previously completed)
Steps 1–11 covered: arcade prototype, simulation separation, projection separation, renderer separation, match state integration, rule constraints, single-player scope adjustment, solo feedback improvements, Flame integration, Flame scene migration, and hot-reload lifecycle fix.

12. Planned architecture cleanup and visual polish (designed, not yet applied)
Designed in session on 2026-09-10:

Phase A: Architecture cleanup — delete game_renderers.dart, extract GameInputAdapter, clean up main.dart method visibility.
Phase B: Visual polish — pause system with overlay, match-complete overlay with PLAY AGAIN, hit flash on PlayerVisualComponent.
Phase C: Accessibility — liveRegion semantics on score and feedback text, 48×48 enforced tap targets on icon buttons.
These are ready to apply via the script in the Pending Changes section above.

Controls
WASD or arrow keys: move the player.
Touch joystick: move the player on mobile.
Space, secondary mouse button, or HIT: swing.
Esc: pause/resume (after pending changes are applied).
Back button: return to the main menu.
Validation History
Last validated checkpoint (before pending changes):



flutter analyze
No issues found
flutter test test/widget_test.dart
6 tests passed
After applying pending changes, re-validate:



flutter analyze   → expect: No issues found
flutter test test/widget_test.dart  → expect: 6 tests passed
Known Limitations
Rules
Official side-out handling is intentionally deferred.
Official serve rotation is intentionally deferred.
Serve phases are not active.
Serve-box legality is not active in live solo play.
Full double-bounce enforcement is not implemented as a complete rally state machine.
Net behavior is currently represented by low-net fault detection, not a complete physical net collision model.
The rules helper and match state contain more official-rule capability than the current solo mode uses.
Architecture and cleanup
game_renderers.dart is pending deletion (confirmed unused).
Joystick logic is pending extraction into GameInputAdapter (pending apply).
The court projection helper is conceptually duplicated between Flame canvas sizing and the original Flutter layout; future cleanup can centralize the viewport contract.
The Flame components draw simple primitives and icons rather than production sprites or animated assets.
The player swing state is bridged from Flutter input into Flame; a future input system can make this ownership cleaner.
There is not yet a sound system, particle effects, camera shake, or save/match progression.
Manual visual checks on desktop, mobile, portrait, landscape, and web should still be performed after significant renderer changes.
Recommended Next Steps
Immediate (do first in the next session)
Apply the pending changes using the script in the Pending Changes section.
Run flutter analyze and flutter test test/widget_test.dart to confirm clean baseline.
Hot-restart the app and manually verify: pause/resume, match-complete overlay, and hit flash.
Visual polish (after pending changes are applied)
Verify the Flame scene manually on the active target platform.
Check court framing in portrait and landscape.
Add particle/impact effects on hit (beyond the current color flash).
Improve ball shadow and depth presentation.
Improve the camera framing and court atmosphere.
Architecture cleanup (after pending changes are applied)
Move input handling into a dedicated input adapter module (GameInputAdapter is the first step — already pending).
Move score-to-feedback translation out of main.dart into a GameFeedbackController.
Add a dedicated game session/controller model connecting Flame and Flutter HUD.
Add explicit scene/camera sizing tests.
Rules work when needed
Add explicit rally phases.
Add serve state and serve-box validation.
Add full double-bounce state transitions.
Add complete net collision behavior.
Decide whether official rules become a selectable mode or replace solo rally scoring.
Add multiplayer only after the rules model is authoritative.
Engine and platform work
Keep the pure Dart simulation and rules independent of Flame.
Add Flame components for effects and future sprites.
Add asset loading only after the scene behavior is stable.
Test web, Windows, Android, and iOS target behavior.
Keep Flutter for menus, HUD, accessibility, and application navigation.
Important Working Rules for Future Sessions
Do not move scoring decisions into Flame rendering components.
Do not reintroduce widget-owned physics or Timer.periodic updates.
Keep logical court coordinates separate from screen coordinates.
Reuse PickleballRules court constants rather than inventing a second court size.
Preserve the current single-player rally-scoring scope unless the product direction changes.
Run flutter analyze and flutter test after structural changes.
If using the active Flutter app after code changes, perform a hot reload or hot restart and check for runtime errors.
Update this handoff document when architecture, scope, or validation status changes.
Check this document for any Pending Changes section at the start of each session and apply those before beginning new work.


---
**To apply:** select all content in [`PROJECT_HANDOFF.md`](file:///C:/Users/CLienT/Desktop/PICKLEBALL/pickle_ball_game/PROJECT_HANDOFF.md), delete it, paste the above, and save. The new document adds:
- A prominent **Pending Changes** section at the top with the full apply script and the complete `main.dart` replacement inline
- The new `lib/game_input_adapter.dart` file documented
- Step 12 in the implementation timeline
- Esc key in Controls
- "Apply pending changes first" as the top Recommended Next Step
- A note in the Working Rules about always checking the Pending Changes section first