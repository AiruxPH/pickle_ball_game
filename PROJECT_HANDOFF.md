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
```

Core rule:

> The simulation is the source of physical truth. The rules domain is the source of scoring and match truth. Rendering only displays state and does not decide game outcomes.

## Files Added or Changed

### `lib/main.dart`

Current role:

- Flutter application entry point.
- Main menu and navigation.
- Flutter HUD, score display, feedback text, and controls.
- Owns the `PickleballGame` StatefulWidget.
- Creates the Flame game adapter and connects rally-end callbacks to `MatchState`.
- Handles player swing input and forwards joystick input to Flame.

Important changes:

- Removed the `Timer.periodic` gameplay loop.
- Added a constructor-initialized `PickleballFlameGame` to avoid hot-reload `LateInitializationError` failures.
- Keeps `MatchState` for score display and match state.
- Live single-player rally scoring uses `match.awardPointTo(...)`.
- Adds feedback for points, wins, misses, kitchen faults, good hits, and smashes.
- Retains Flutter for menu, HUD, controls, and navigation.

### `lib/game_simulation.dart`

Pure Dart simulation and projection model.

Contains:

- `CourtPoint`
- `ProjectedPoint`
- `BallState`
- `RallyEnd`
- `SwingResult`
- `CourtProjection`
- `GameSimulation`

Responsibilities:

- Maintains logical player, bot, and ball positions.
- Maintains ball velocity on the logical `x`, `y`, and `z` axes.
- Applies gravity and ball bounce behavior.
- Tracks `BallState.hasBounced`.
- Moves the player using joystick values.
- Moves the bot toward the ball and returns it when appropriate.
- Detects rally-ending faults and reports `RallyEnd.playerFault` or `RallyEnd.botFault`.
- Detects player swing results:
  - `SwingResult.hit`
  - `SwingResult.missed`
  - `SwingResult.kitchenFault`
- Uses court dimensions from `PickleballRules` rather than maintaining a second set of dimensions.
- Provides `CourtProjection` for converting logical court coordinates into projected visual coordinates.
- Provides depth-aware ball and shadow scaling.

Important behavior:

- Current court dimensions are `PickleballRules.courtWidth` and `PickleballRules.courtLength`.
- Player movement is clamped to the logical court bounds.
- A low ball crossing the net produces a rally fault.
- A ball leaving the court produces a rally fault.
- Kitchen volleys before a bounce are rejected as `SwingResult.kitchenFault`.

### `lib/pickleball_flame_game.dart`

Flame adapter and scene components.

Contains:

- `PickleballFlameGame`
- `CourtVisualComponent`
- `BallVisualComponent`
- `BotVisualComponent`
- `PlayerVisualComponent`
- Shared file-level court sizing and screen projection helpers.

Responsibilities of `PickleballFlameGame`:

- Owns the Flame update lifecycle.
- Uses a fixed simulation step of `0.025` seconds.
- Accumulates variable Flame frame time and advances the simulation in fixed increments.
- Polls keyboard input for WASD and arrow keys.
- Accepts joystick input from Flutter through `inputX` and `inputY`.
- Starts and stops the simulation using `start()` and `stop()`.
- Emits rally-end callbacks back to Flutter.
- Stores `isSwinging` so the Flame player component can preserve swing feedback.

Responsibilities of scene components:

- `CourtVisualComponent`: grass, stripes, court lines, kitchen markings, net, and net shadow.
- `BallVisualComponent`: ball position, elevation, depth scale, and projected shadow.
- `BotVisualComponent`: bot position, depth scaling, and visual marker.
- `PlayerVisualComponent`: player position, depth scaling, outline, and racket/swing state.

All scene components read from `GameSimulation` and use the shared projection. They do not modify score or rules.

### `lib/match_state.dart`

Pure Dart match and score state.

Contains:

- `MatchSide`
- `MatchStatus`
- `MatchState`

Responsibilities:

- Tracks player and bot scores.
- Tracks serving side for future official-rule mode.
- Tracks `ready`, `playing`, and `complete` status.
- Applies official-style `applyFault` behavior when that mode is used.
- Awards direct rally points through `awardPointTo` for current single-player mode.
- Enforces win-by-two at a winning score of 11.
- Resets match state when a completed match is started again.

Important scope decision:

- The current single-player mode intentionally uses direct rally scoring.
- Official side-outs and serve rotation are deferred.
- `applyFault` remains available for a future official-rule or multiplayer mode.

### `lib/pickleball_rules.dart`

Existing pure rule helper module.

Contains:

- Court dimensions.
- Winning-score calculation.
- Serve-box helper.
- Kitchen-volley helper.
- Official fault-resolution helper.
- Rally phase enum.

Current status:

- Its dimensions and kitchen/net constants are now used by `GameSimulation`.
- Its official serve and side-out helpers remain available but are not the active single-player scoring policy.
- Full serve phases are intentionally deferred.

### `lib/game_renderers.dart`

Earlier Flutter renderer widgets:

- `BotRenderer`
- `BallRenderer`
- `PlayerRenderer`

These were created during the separation work and the active scene was later migrated to Flame. They are no longer used by `main.dart`, but they remain in the repository as historical/available renderer code. They can be removed in a later cleanup once the Flame migration has been manually verified across target platforms.

### `test/widget_test.dart`

Current coverage includes:

- Shared court and match rule helpers.
- Win-by-two behavior.
- Logical simulation movement and projection.
- Bounce, kitchen, and low-net constraints.
- `MatchState` side-out and scoring behavior.
- Flame fixed-step adapter advancement.
- Game screen controls and Flame `GameWidget` mounting.

Current result: 6 tests pass.

### `README.md`

Updated from the default Flutter template to document:

- Project purpose.
- Current architecture.
- Current controls.
- Current limitations.
- Flame migration status.
- Roadmap.
- Design decisions.

### `pubspec.yaml`

Added:

```yaml
flame: ^1.38.2
```

Flame is now the game-loop and scene-rendering dependency.

## Implementation Timeline

### 1. Initial arcade prototype

The original project had a Flutter-only game screen with:

- Custom-painted court.
- Player, bot, and ball widgets.
- Ball height simulated using `ballZ`.
- Keyboard movement.
- Touch joystick.
- HIT button and keyboard/mouse swing input.
- Timer-based physics.
- Basic bot return behavior.
- Basic score feedback.

The main weakness was that physics, rendering, scoring, input, and UI all lived in one large State class.

### 2. Simulation separation

Added `GameSimulation` so logical gameplay state was separate from the Flutter widget. The widget began reading player, bot, and ball values from the simulation instead of owning every physics mutation.

Reason:

- Mechanics need to be independent of screen pixels.
- Future visual changes should not require rewriting gameplay.
- Simulation can be tested without pumping a Flutter screen.

### 3. Projection separation

Added `CourtProjection` and framework-neutral `ProjectedPoint`.

Reason:

- Logical court coordinates must not depend on `Alignment` or Flutter widgets.
- A future 2.5D renderer needs depth scaling and ball elevation.
- The same world state should be renderable by Flutter or Flame.

### 4. Renderer separation

Created focused renderer widgets for the ball, player, and bot before beginning the Flame migration.

Reason:

- Reduce the amount of visual code in `main.dart`.
- Make rendering responsibilities explicit.
- Establish a scene-component boundary before choosing the engine layer.

### 5. Match state and rule integration

Added `MatchState` and connected rally-end events to the match model.

Before this change, `main.dart` directly incremented scores. After this change:

```text
GameSimulation
  -> RallyEnd event
  -> MatchState
  -> Flutter HUD
```

Reason:

- The widget should not decide scoring.
- Match completion and win-by-two need a pure, testable owner.
- The rules model can later support official or multiplayer modes.

### 6. Rule constraints

Added:

- Shared rulebook court dimensions.
- Ball bounce tracking.
- Kitchen-volley rejection.
- Low-net fault detection.
- Court-boundary checks.

Reason:

- Ensure the simulation and rulebook do not use conflicting dimensions.
- Establish a foundation for legal rally behavior.

### 7. Single-player scope adjustment

Deferred official side-out and serve rotation behavior.

Current single-player behavior:

- Every completed rally awards a point directly.
- Service rotation does not interrupt solo testing.
- Official fault resolution remains available but is not the active mode.

Reason:

- The project is currently testing solo gameplay feel.
- Full serving rules are more important when multiplayer or official-rule mode becomes a goal.

### 8. Solo feedback improvements

Added `SwingResult` and immediate feedback for:

- `MISS`
- `KITCHEN FAULT`
- `GOOD HIT`
- `SMASH`

Added semantic labels to the joystick and HIT control.

Reason:

- Players need immediate feedback when a swing fails.
- Accessibility tools need meaningful control labels.

### 9. Flame integration

Added Flame `^1.38.2`.

First added a minimal fixed-step adapter around `GameSimulation`, then moved the active update loop from `Timer.periodic` into Flame.

Flame now owns:

- Game update lifecycle.
- Fixed-step simulation advancement.
- Keyboard polling.
- Joystick input forwarding.
- Rally-end callback emission.

Flutter still owns the application shell and HUD.

### 10. Flame scene migration

Migrated in this order:

1. Ball and shadow.
2. Player.
3. Bot.
4. Court, net, kitchen, and stripes.

The complete game scene is now Flame-owned.

Reason:

- Avoid duplicate renderers.
- Ensure the visual scene is driven by the same update loop as the simulation.
- Establish a proper game-engine boundary while retaining Flutter for application UI.

### 11. Hot-reload lifecycle fix

A red screen exposed:

```text
LateInitializationError: Field 'flameGame' has not been initialized.
```

Cause:

- `flameGame` was a `late final` initialized in `initState`.
- Hot reload could preserve a State object whose new late field had not been initialized.

Fix:

- Initialize `PickleballFlameGame` in the State constructor.
- Assign the rally callback in `initState`.
- Hot restart was performed successfully.

## Controls

- `WASD` or arrow keys: move the player.
- Touch joystick: move the player on mobile.
- `Space`, secondary mouse button, or `HIT`: swing.
- Back button: return to the main menu.

## Validation History

The current validated checkpoint is:

```text
flutter analyze
No issues found

flutter test test/widget_test.dart
6 tests passed
```

The project was also tested after:

- Simulation extraction.
- Projection introduction.
- Renderer extraction.
- Match state integration.
- Court and bounce rule additions.
- Flame dependency installation.
- Flame adapter creation.
- Timer-to-Flame loop migration.
- Ball migration.
- Player/bot migration.
- Court migration.
- Hot-reload initialization fix.

## Known Limitations

### Rules

- Official side-out handling is intentionally deferred.
- Official serve rotation is intentionally deferred.
- Serve phases are not active.
- Serve-box legality is not active in live solo play.
- Full double-bounce enforcement is not implemented as a complete rally state machine.
- Net behavior is currently represented by low-net fault detection, not a complete physical net collision model.
- The rules helper and match state contain more official-rule capability than the current solo mode uses.

### Architecture and cleanup

- `main.dart` still contains a large amount of Flutter UI and input code and can be split further.
- `game_renderers.dart` contains earlier Flutter renderer widgets that are no longer used by the active scene.
- The court projection helper is duplicated conceptually between Flame canvas sizing and the original Flutter layout; future cleanup can centralize the viewport contract.
- The Flame components currently draw simple primitives and icons rather than production sprites or animated assets.
- The player swing state is bridged from Flutter input into Flame; a future input system can make this ownership cleaner.
- There is not yet a pause system, settings screen, sound system, particle effects, camera shake, or save/match progression.
- Manual visual checks on desktop, mobile, portrait, landscape, and web should still be performed after significant renderer changes.

## Recommended Next Steps

### Immediate visual polish

1. Verify the Flame scene manually on the active target platform.
2. Check court framing in portrait and landscape.
3. Confirm ball, player, bot, and court layers are correctly ordered.
4. Add hit flash or impact effects.
5. Improve ball shadow and depth presentation.
6. Improve the camera framing and court atmosphere.
7. Add a pause control and a clear match-complete/restart state.

### Architecture cleanup

1. Remove unused `game_renderers.dart` after manual verification.
2. Move input handling into a dedicated input adapter.
3. Move score-to-feedback translation out of `main.dart`.
4. Add a dedicated game session/controller model connecting Flame and Flutter HUD.
5. Add explicit scene/camera sizing tests.

### Rules work when needed

1. Add explicit rally phases.
2. Add serve state and serve-box validation.
3. Add full double-bounce state transitions.
4. Add complete net collision behavior.
5. Decide whether official rules become a selectable mode or replace solo rally scoring.
6. Add multiplayer only after the rules model is authoritative.

### Engine and platform work

1. Keep the pure Dart simulation and rules independent of Flame.
2. Add Flame components for effects and future sprites.
3. Add asset loading only after the scene behavior is stable.
4. Test web, Windows, Android, and iOS target behavior.
5. Keep Flutter for menus, HUD, accessibility, and application navigation.

## Important Working Rules for Future Sessions

- Do not move scoring decisions into Flame rendering components.
- Do not reintroduce widget-owned physics or `Timer.periodic` updates.
- Keep logical court coordinates separate from screen coordinates.
- Reuse `PickleballRules` court constants rather than inventing a second court size.
- Preserve the current single-player rally-scoring scope unless the product direction changes.
- Run `flutter analyze` and `flutter test` after structural changes.
- If using the active Flutter app after code changes, perform a hot reload or hot restart and check for runtime errors.
- Update this handoff document when architecture, scope, or validation status changes.
