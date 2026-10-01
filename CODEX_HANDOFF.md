# Codex Handoff

## Project

Repository: AiruxPH/pickle_ball_game

This is a Flutter + Flame pickleball game. Continue from the current repository state instead of rebuilding the gameplay systems from scratch.

The user prefers readable, beginner-friendly Dart and incremental changes that can be tested after each feature.

## Current architecture

Important files:

- `lib/game_simulation.dart` contains the main simulation: ball physics, player movement, bot AI, hit detection, serving, rally rules, camera-related simulation state, and practice mode.
- `lib/pickleball_flame_game.dart` renders the simulation with Flame and consumes gameplay events for visual behavior.
- `lib/match_state.dart` owns scoring and service possession.
- `lib/pickleball_rules.dart` contains court dimensions and reusable rule checks.
- `lib/game_input_adapter.dart` handles the virtual joystick.
- `lib/main.dart` connects Flutter UI, input, MatchState, GameSimulation, and Flame.
- `test/widget_test.dart` currently contains both gameplay regression tests and widget tests.

The simulation uses a fixed step of 0.025 seconds (40 ticks per second).

## Work already completed

### PR #1: gameplay rule/state fixes

- Corrected two-bounce handling.
- Corrected ball-speed conversion to mph.
- Fixed duplicate bot-hit detection caused by rendered frames containing multiple fixed simulation steps.
- Added regression tests.

### PR #2: explicit rally state machine

Added `RallyPhase`:

- `waitingForServe`
- `serveInFlight`
- `receiverMayReturn`
- `serverBounceRequired`
- `openRally`
- `deadBall`

Do not move two-bounce enforcement back to `rallyLength`. `rallyLength` can be used for statistics/gameplay information, but `RallyPhase` is the source of truth for the two-bounce sequence.

Correct sequence:

1. Serve is hit.
2. Receiver must allow the serve to bounce.
3. Receiver returns it.
4. Serving side must allow that return to bounce.
5. After that bounce, normal/open rally rules apply.

### PR #3: serve and bounce faults

- Serve first-bounce validation now uses `RallyPhase.serveInFlight`.
- Serves are checked against the diagonal service box.
- The non-volley-zone/kitchen line counts as part of the kitchen and is therefore a serve fault.
- Outer service-box boundary lines remain in.
- Normal first-bounce out-of-bounds and double-bounce faults have regression coverage.

### PR #4: gameplay event system

`GameSimulation` has an explicit event queue that Flame can drain.

Current event types include:

- `playerHit`
- `botHit`
- `bounce`
- `netFault`
- `outOfBounds`
- `doubleBounce`
- `rallyEnd`

Do not restore renderer-side hit detection based on velocity direction changes. Simulation events should be the source of truth for animations, sound, camera effects, and future VFX.

### PR #5: player shot system

This handoff file is being added to the `feature/player-shot-system` branch, which contains PR #5.

PR #5 adds:

- Two-axis player aiming.
- Joystick X controls left/right shot placement.
- Joystick Y controls short/deep shot placement.
- `ShotQuality`: `early`, `good`, and `perfect`.
- Contact quality changes shot power/trajectory.
- High-ball contact becomes a faster, flatter smash.
- `playerHit` events carry shot quality and smash information.
- Tests for aiming, contact quality, and smashes.

Before doing additional work, check whether PR #5 has been merged into `main`. If it has not, work from the feature branch or merge/rebase only with the user's approval.

## Important gameplay behavior

Scoring uses traditional side-out scoring through `MatchState.resolveRally()`:

- The serving side scores when it wins a rally.
- The receiving side winning a rally causes a side-out but does not score.
- Games require at least 11 points and a 2-point lead.

The player and bot use opposite halves of the court. Preserve the current coordinate convention when modifying shot targeting or service-box calculations.

`BallState.hasBounced` describes whether the current shot has bounced. It should not replace `RallyPhase` for determining the two-bounce sequence.

Practice/free-roam mode intentionally bypasses much of the normal match flow and includes a ball machine. Avoid accidentally applying match-only faults to practice mode.

## Recommended immediate workflow

First run:

```bash
flutter pub get
flutter analyze
flutter test
```

Fix any compile/analyzer/test failures before adding more gameplay features.

Then run the game and play-test PR #5. Pay particular attention to:

- Whether left/right aiming feels intuitive.
- Whether joystick up actually produces a useful deep shot and down produces a useful shorter shot.
- Whether normal returns reliably clear the net.
- Whether smashes are powerful without constantly hitting the net.
- Whether the perfect/good/early contact windows feel fair.
- Whether buffered swings still behave correctly.
- Whether the two-bounce rule still works with buffered hits.

Tune constants rather than redesigning the system if the mechanics are basically correct.

## Recommended next feature after shot tuning

Improve bot behavior so the CPU makes decisions rather than only tracking the ball.

A reasonable progression is:

1. Predict where the ball will arrive/bounce.
2. Choose a recovery position instead of following the current ball position too literally.
3. Select between safe return, aggressive drive/smash, short shot/dink, and lob when those shot types exist.
4. Aim based on player position and available court space.
5. Give difficulty levels different reaction time, movement speed, accuracy, and error rates.

Keep AI decision-making separate from raw ball physics where practical.

## Future cleanup

`game_simulation.dart` is large. Eventually it could be split into physics, player/hit systems, AI, rally/rules, and camera modules. Do not perform a broad architecture rewrite until gameplay is stable. Prefer small, testable PRs.

## Development rules

- Preserve the explicit `RallyPhase` state machine.
- Preserve explicit `GameplayEvent` emission.
- Do not infer gameplay events in the renderer when the simulation can emit them.
- Add regression tests for rule changes and bug fixes.
- Keep changes focused and easy to review.
- Run `flutter analyze` and `flutter test` locally before considering a change complete.
- Do not silently change scoring rules.
- Avoid large refactors while gameplay mechanics are still being tuned.
