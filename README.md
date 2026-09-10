# Pro Pickleball

An arcade-style pickleball game with a fixed elevated 2.5D court view. The
project uses Flutter for the application interface and is structured so the
game simulation, rules, and rendering can evolve independently.

## Current status

- Playable court with player, bot, ball physics, shadows, and depth scaling.
- Keyboard, touch joystick, HIT button, and secondary mouse-button controls.
- Logical simulation coordinates are separate from screen projection.
- Player, bot, and ball visuals are separate renderer widgets.
- Pure Dart `MatchState` now defines serving, scoring, side-outs, and win-by-two
	match completion.
- Live rally-end events now flow from the simulation through `MatchState`; the
	widget no longer increments scores directly.
- Simulation court dimensions now match the rulebook, with bounce tracking,
	kitchen-volley checks, and low-net fault detection.
- Official side-out handling and serve rotation are intentionally deferred
	while we focus on the single-player experience.
- Single-player mode currently awards each completed rally directly, so testing
	is not interrupted by service rotation.
- Swing outcomes now provide immediate `MISS`, `KITCHEN FAULT`, `GOOD HIT`, and
	`SMASH` feedback, with semantic labels on touch controls.
- Flame `^1.38.2` is installed with a fixed-step adapter ready for the game-loop
	migration; the current Flutter screen is still the active renderer.

## Architecture

```text
Flutter UI
	Menu, HUD, controls, navigation

Game simulation
	Logical positions, ball physics, movement, hit detection

Rules domain
	MatchState, serving, faults, scoring, match completion

Rendering
	Court painter, projection, player, bot, ball, and shadow renderers
```

The intended future game layer is Flame inside Flutter. Flame will own the game
loop and scene components, while the pure Dart rules domain remains independent
of Flutter and Flame.

## Controls

- `WASD` or arrow keys: move the player.
- Touch joystick: move the player on mobile.
- `Space`, secondary mouse button, or `HIT`: swing.
- Back button: return to the main menu.

## Development

Run the analyzer:

```text
flutter analyze
```

Run the tests:

```text
flutter test
```

## Progress roadmap

1. Define and test the pure Dart match rules. **Complete.**
2. Connect live rally events to `MatchState`. **Complete.**
3. Improve solo rally behavior, feedback, and court interaction. **In progress.**
4. Move the live simulation loop into the Flame adapter and add scene components.
5. Return to full serve phases, serve-box legality, and side-out handling for
	multiplayer or official-rule play.

## Design decisions

- The simulation is the source of physical truth.
- The rules domain is the source of scoring and match truth.
- Rendering only displays state and never decides game outcomes.
- The current visual target is an elevated overhead 2.5D view, not a full
	third-person 3D camera.
