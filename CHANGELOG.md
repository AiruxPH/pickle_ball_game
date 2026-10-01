# Changelog

All notable changes, fixes, and improvements to the Pickleball Game are documented here. This serves as persistent memory for the codebase.

---

## [2026-10-01 20:25:00 +08:00] - Cloth-like Net Collisions: Inelastic Energy Absorption, Soft Drop Physics, and Dynamic Mesh Flex/Ripple

### 1. Inelastic Cloth Collision Physics & Boundary Enforcement
- **Cause of Error**:
  - Previously, when the ball hit below regulation net height ($Z < 0.1364$), the game merely registered a fault in match modes or streak reset in practice mode without altering the ball's physical velocity or trajectory. The ball would phase cleanly through the net plane into the opponent's court and continue flying.
- **Reason of Change**:
  - Implement realistic cloth net behavior where the flexible mesh absorbs the ball's kinetic energy and drops it gently to the court floor on the incoming side, preventing unrealistic clipping and bouncy rubber-like rebounds.
- **Changes**:
  - In `lib/game_simulation.dart`, implemented net plane collision detection:
    `crossedNetPlane = (previousBallY < 0 && ball.y >= 0) || (previousBallY > 0 && ball.y <= 0)` with $Z \in [0, \text{netHeight}]$ and $|X| \le \text{courtWidth} \times 1.15$.
  - **Inelastic Cloth Damping**:
    - Rebound velocity: $V_y = -V_y \times 0.12$ (absorbing ~88% of forward kinetic energy).
    - Lateral friction: $V_x \times 0.35$ against the mesh cord.
    - Vertical slide: $V_z$ damped to $(V_z \times 0.20)$ clamped in $[-0.01, 0.006]$, causing the ball to slide softly down the net face to the floor.
  - **Side Constraint**:
    - Constrained ball position $Y = \text{fromPlayerSide} ? 0.025 : -0.025$, ensuring the ball never passes through the net plane upon contact.
  - **State Integration**:
    - In match modes, immediately ends the rally via `_endRally(faultSide, cause: GameplayEventType.netFault)`.
    - In free-roam practice mode, resets `practiceStreak = 0`, emits `GameplayEventType.netFault`, and lets the ball drop and roll on the player's side.

### 2. Dynamic Net Cloth Flex & Ripple Mesh Rendering
- **Reason of Change**:
  - Provide tangible, physical visual feedback when the ball strikes the net. Rather than a static, rigid wall, the net now reacts like real woven sports mesh cloth, bulging outward at the point of impact and damping back to rest.
- **Changes**:
  - Added deformation telemetry to `GameSimulation`: `netImpactX`, `netImpactIntensity`, `netImpactDirection`, and `onNetHit` callback.
  - In `CourtVisualComponent.render` (`lib/pickleball_flame_game.dart`):
    - Computed continuous Gaussian displacement along $X$ and sinusoidal tension along $Z$:
      `netYOffset(x, z) = impactDir * intensity * 0.035 * sin(z / netHeight * pi / 2) * exp(-dx * dx / 0.025)`
    - Applied dynamic displacement to the net mesh polygon, vertical grid lines, horizontal mesh lines, and top white tape.
    - Decayed `netImpactIntensity` each tick (both active rally and dead ball) back to zero.

### 3. Audio-Visual Feedback & Haptics
- **Reason of Change**:
  - Polish the sensory feel of hitting the net across both match and practice modes.
- **Changes**:
  - In `lib/pickleball_flame_game.dart`, added `GameplayEventType.netFault` handler triggering `spawnHitEffect(isSmash: false)`.
  - In `lib/main.dart`, hooked `flameGame.simulation.onNetHit` to trigger light haptic feedback (`HapticFeedback.lightImpact()`) and display referee feedback banner `"NET FAULT!"` during practice mode.

---

## [2026-10-01 19:35:00 +08:00] - Refine Bot vs Bot POVs: Zoom In Side/Top Views, Eliminate Black Floor Clipping, and Enforce Stadium Bounds in Free Roam

### 1. Zoom In on Side View (Broadcast Camera) & Smooth Rally Tracking
- **Reason of Change**:
  - Bring the broadcast camera closer to the court so spectators can clearly see player animations, paddle contact, and ball bounces without distant pixelation.
  - Implemented:
    - Shifted `CameraMode.broadcast` camera position from distant $X = 2.5, Z = 1.5$ to tournament sideline elevation $X = 1.35, Z = 0.78$.
    - Added subtle $Y$-axis camera panning in `updateDynamics` (`targetLookY = ballY * 0.20`), smoothly tracking the rally action between the top and bottom bot.

### 2. Zoom In on Top-Down View
- **Reason of Change**:
  - In top-down mode, the court was excessively small in the center with over 50% of the screen wasted on empty navy blue void.
  - Implemented:
    - Lowered top-down altitude from $Z = 3.5$ to $Z = 2.15$, framing the court, baselines, and both bots from top to bottom.

### 3. Eliminate Broadcast Floor Clipping & Black Voids
- **Cause of Error**:
  - In `lib/pickleball_flame_game.dart`, the stadium floor was restricted to `boundsW = 1.232` and `floorFront = 1.75`. Because the previous broadcast camera was placed at $X = 2.5$, it was floating outside the arena geometry looking across unpainted space, creating a large black void at the bottom edge.
- **Reason of Change**:
  - Ensure the arena floor is seamless and solid from every camera perspective.
- **Changes**:
  - In `CourtVisualComponent.render`, rendered `stadiumBaseFloorPaint` covering the full foundation floor ($X \in [-floorW, floorW], Y \in [-floorBack, floorFront]$).
  - Extended `floorFront` from $1.75$ to `length * 6.0`.
  - Expanded stadium walls to `boundsW = width * 3.4` ($\approx 1.50$) so the sideline camera sits inside the arena.

### 4. Limit Free Roam Mode Strictly Inside the Stadium
- **Cause of Error**:
  - `freeRoamX`, `freeRoamY`, and `freeRoamZ` had no bounding constraints, allowing the camera to float into the dark abyss beyond the stadium walls or zoom out to $Z = 10.0$.
- **Reason of Change**:
  - Keep the free roam camera grounded and enclosed within the stadium environment as requested by the user.
- **Changes**:
  - In `GameSimulation.update()`, clamped `freeRoamX` within $\pm 1.10$, `freeRoamY` between $-2.0$ (grandstand back) and $1.55$ (front boundary), and `freeRoamZ` between $0.4$ and $2.8$.
  - Updated `GestureDetector.onScaleUpdate` in `lib/main.dart` to clamp scale within $0.4\text{--}2.8$ and pitch between $-\pi / 2.2$ and $\pi / 6.0$.
  - Adjusted `_buildAltitudeSlider()` range from $1.0\text{--}10.0$ to $0.4\text{--}2.8$ with safe clamped values.
  - Reset default initial `freeRoam` position from $(0.0, 2.0, 4.0)$ to $(0.0, 1.4, 1.8)$ inside the stadium.

---

## [2026-10-01 19:15:00 +08:00] - Practice Mode Redesign: Full Facility HUD, Ball Machine Drills, Regulation Court & Net, and Dynamic Target Landing Zones

### 1. Comprehensive Practice Mode HUD & Interactive Drill Settings
- **Reason of Change**:
  - Elevate the practice experience from an empty sandbox to an arcade-grade training facility with instant feedback, goal-oriented target practice, and customizable ball feeds.
  - Implemented:
    1. **Practice HUD Header (`PracticeHud`)**: Styled with `AngularFrame` (beveled cuts, metallic edges, cyber fill), featuring a drill type chip (tappable to cycle), current & best streak counter with flame icon, target zone points tracker, instant "FEED BALL" button, and drill configuration button.
    2. **Practice Drills Modal (`PracticeDrillsDialog`)**: Styled with `AngularFrame`, providing drill selection (`Dinks` for soft kitchen drops, `Drives` for fast baseline penetration, `Lobs` for high arcing smash practice, and `Random`), Auto Feed toggle with feed interval slider (1.5s to 4.5s), and a stat reset action.
    3. **Key F Feed Shortcut**: Desktop keyboard support to immediately fire a training ball with the `F` key.

### 2. Ball Machine Physics & Dynamic Training Drills
- **Reason of Change**:
  - Provide distinct, realistic shot behaviors for different pickleball training drills:
    - **Dinks**: Soft drop shots targeted near the kitchen line ($y \approx 0.28\text{--}0.42$) with low velocity ($v = 0.021$) and gentle arch ($v_z = 0.016$).
    - **Drives**: Penetrating baseline drives targeted deep ($y \approx 0.70\text{--}0.90$) with fast velocity ($v = 0.031$) and low net clearance ($v_z = 0.019$).
    - **Lobs**: High arcing ball feeds targeted deep ($y \approx 0.78\text{--}0.95$) with high vertical velocity ($v_z = 0.033$) tailored for overhead smash practice.

### 3. Dynamic Court Target Zones & Streak Multipliers
- **Reason of Change**:
  - Give players clear, rewarding landing targets on the opponent's court to practice placement accuracy:
    - Defined 5 distinct court target zones (`Deep Left`, `Deep Right`, `Deep Center`, `Kitchen Drop L`, `Kitchen Drop R`).
    - Added target hit detection with score awards ($50\text{--}100$ pts) and streak-based multipliers ($1.5\times$ at streak 5+, $2.0\times$ at streak 10+).
    - Rendered targets in 3D perspective foreshortening directly on the opponent court surface with glowing outer rings, holographic fills, and bullseye centers for the active target.

### 4. Fix Practice Facility Missing Net, Kitchen, and Court Lines
- **Cause of Error**:
  - In `lib/pickleball_flame_game.dart` (`CourtVisualComponent.render`), the `MapType.practiceFacility` conditional executed an early `return; // No net or kitchen for practice facility` immediately after rendering the concrete floor and benches.
  - This prevented the court floor, non-volley kitchen lines, baseline, center line, and regulation net from ever being drawn, leaving players on a blank concrete floor with no net to practice clearing or dinking over.
- **Reason of Change**:
  - Restore full regulation court geometry, kitchen floor, lines, and 3D net in the practice facility so players can practice authentic net clearance, kitchen drops, and line shots.
- **Changes**:
  - Removed early return; rendered high-tech dark slate teal training court floor, non-volley kitchen zone, regulation lines, and full net mesh/tape/posts.
  - Added `_drawPracticeTargetZones()` to project holographic target zones onto the court floor.

### 5. Fix Faults Interrupting Practice Sessions & Match Scoring
- **Cause of Error**:
  - In `lib/main.dart`, when a kitchen violation or two-bounce fault occurred during practice, `_executeSwing()` invoked `_handleRallyEnd()`, which awarded CPU points and triggered match-end screens ("POINT FOR CPU!", "CPU WINS").
- **Reason of Change**:
  - Ensure practice mode is continuous: faults reset the practice streak and show referee feedback without modifying match points or stopping the session.
- **Changes**:
  - Added `if (widget.gameMode == 2) return;` guard in `_handleRallyEnd()`.
  - Updated `_executeSwing()` to reset `simulation.practiceStreak = 0` on faults during practice mode without ending the rally.

### 6. Fix Deprecated `Switch.activeColor`
- **Cause of Error**:
  - In `lib/widgets/practice_hud.dart`, `Switch` used `activeColor`, which is deprecated after Flutter v3.31 in favor of `activeThumbColor`.
- **Reason of Change**:
  - Eliminate deprecation warning and maintain clean static analysis.
- **Changes**:
  - Replaced `activeColor: AppTheme.accentLime` with `activeThumbColor: AppTheme.accentLime`.

---

## [2026-10-01 18:46:00 +08:00] - Extend AngularFrame Aesthetic Across Modals and Settings/Profile Panels & Fix Overflow

### 1. Apply AngularFrame to Dialogs, Pause Menu, Settings, and Profile
- **Reason of Change**:
  - Unify the arcade/cyberpunk visual identity across all modal popups and content containers by utilizing `AngularFrame` (beveled/angular cut corners, metallic stroke, inner highlights, and ambient shadow) instead of standard rounded rectangles.
  - User requested applying `AngularFrame` to:
    1. In-game Pause menu (`_buildPauseOverlay` and `_showConfirmationDialog` in `lib/main.dart`).
    2. CPU Difficulty selection dialog in `lib/screens/main_menu_screen.dart`.
    3. Game Mode selection dialog in `lib/screens/main_menu_screen.dart`.
    4. Controls and Accessibility settings container in `lib/screens/settings_screen.dart`.
    5. Player Profile cards (Header profile card, stat cards, and 3D equipment showcase) in `lib/screens/profile_screen.dart`.
- **Changes**:
  - `lib/widgets/angular_frame.dart`: Added optional `width` and `height` properties to `AngularFrame` to cleanly size containers; synchronized `topBevel` path calculations with the clamped cut value.
  - `lib/main.dart`: Replaced the rounded container in `_buildPauseOverlay()` and `_showConfirmationDialog()` with `AngularFrame` featuring amber accents, cut corners, and cyber gradient backdrops.
  - `lib/screens/main_menu_screen.dart`: Replaced modal containers in `_showDifficultyDialog()` and `_buildStartMatchButton()` (Game Mode Picker) with `AngularFrame`.
  - `lib/screens/settings_screen.dart`: Replaced `Container(decoration: AppTheme.glassPanel)` with `AngularFrame` with cyan accent and 18px corner cut.
  - `lib/screens/profile_screen.dart`: Applied `AngularFrame` to the player header card, stat summary cards (`MATCHES`, `WINS`, `LONGEST RALLY`), and the 3D equipment showcase container.

### 2. Fix 14px Right Overflow on CPU Difficulty Dialog
- **Cause of Error**:
  - In `lib/screens/main_menu_screen.dart`, the difficulty and game mode option dialog container was set to a narrow fixed width of `320px` with `24px` horizontal padding on each row. The subtitle text `"Slower reactions and more mistakes"` exceeded the remaining horizontal text layout bounds, triggering a 14-pixel layout overflow on the right edge.
- **Reason of Change**:
  - Eliminate the pixel overflow error and ensure text content scales and wraps smoothly without visual distortion on all screen sizes.
- **Changes**:
  - Increased dialog width from `320px` to `350px`.
  - Adjusted row horizontal padding to `20px` and set `maxLines: 2` with `TextOverflow.ellipsis` for subtitle labels to guarantee proper flex wrapping without overflows.

---

## [2026-10-01 15:05:00 +08:00] - Fix Mid-Game Ball Disappearance, Repeated Same-Side Bot Serve, and Asymmetric Hitbox Precision

### 1. Mid-Game Ball Disappearance & Errant Faults
- **Cause of Error**:
  - The two-bounce rule check (`rallyLength < 3 && !ball.hasBounced`) in swing execution and buffering falsely evaluated all unbounced balls during early rally shots as illegal volleys, even when the player was merely swinging as the ball was descending toward the ground to bounce.
  - In `update()`, both `onPlayerFault` and `return RallyEnd.playerFault` were triggered in the exact same tick, executing `_handleRallyEnd` twice. This double-invoked scoring, cancelled the delay, and caused the ball to instantly freeze into a dead state while resetting immediately.
  - When the bot hit a ball at low elevation, if `ball.z <= 0` before crossing the net ($Y < 0$), `isInsideCourt(x, y)` checked only `y.abs() <= courtLength`, which was true. The ball registered a bounce on the bot's own side of the net (`ball.hasBounced = true`). When the ball subsequently crossed over and touched the player's court for the first time, it hit the double-bounce branch, erroneously faulting the player and causing the ball to vanish on arrival.
  - The airborne out-of-bounds check (`ball.x.abs() > courtWidth * 1.5`) prematurely terminated playable wide shots in mid-air.
- **Reason of Change**:
  - Allow natural, smooth rallies where descending balls can bounce and be returned without premature fault interruption.
  - Ensure strict separation between the hitter's court and the receiver's court: balls that bounce on the hitter's side of the net are immediately ruled a fault on the hitter, not the receiver.
  - Broaden airborne boundaries so wide recoveries and deep baseline returns are never killed in mid-air.
- **Changes**:
  - Created `isTwoBounceViolation({required bool forPlayer})` following official USA Pickleball rules (only shots 0 and 1 must bounce; volleys outside the kitchen are fully legal from shot 2 onward).
  - Prevented premature two-bounce faults during buffered swings while the ball is descending (`ball.z > 0.12`).
  - Added net-side verification on bounce: `lastHitByPlayer && ball.y >= 0` faults the player; `!lastHitByPlayer && ball.y <= 0` faults the bot.
  - Removed duplicate `onPlayerFault` callback to ensure `_handleRallyEnd` is called exactly once per rally end.

### 2. Repeated Same-Side Bot Serve Bug
- **Cause of Error**:
  - In `GameSimulation.triggerServe()`, the bot's serve target was computed as `targetX = isEven ? 0.227 : -0.227`. When `isEven == true`, the bot stood at `serveX = 0.25` (positive X) and aimed at `+0.227` (positive X).
  - This sent the serve straight down the line rather than cross-court. `PickleballRules.isServeInCorrectBox` rejected the serve as illegal (`x <= 0` expected), causing an immediate server fault on the bot.
  - Because the bot faulted on every serve, its score never advanced from 0, leaving `isEven` persistently true and causing the bot to serve repeatedly from the exact same side without alternating.
- **Reason of Change**:
  - Ensure the bot serves diagonally cross-court into the legal service box, allowing valid serves and correct scoring progression.
- **Changes**:
  - Corrected bot serve targeting to `targetX = isEven ? -0.227 : 0.227`, ensuring diagonal cross-court trajectory.

### 3. Hitbox Accuracy & Asymmetric Forward Reach
- **Cause of Error**:
  - The previous hit volume used a symmetric box centered at `(playerX, playerY)`. Because the character faces the net ($-Y$), paddle reach extends significantly forward in front of the character, but minimally behind their back.
  - A symmetric radius of 0.20-0.32 was too shallow in front: balls visually approaching the paddle were outside the box.
  - Perspective projection also made 3D depth difficult to judge visually without intermediate height guides.
- **Reason of Change**:
  - Provide a mathematically and visually accurate hit volume reflecting ergonomic forward paddle reach.
  - Ensure 100% visual correspondence between what the user sees in debug mode and the physical hit detection.
- **Changes**:
  - Implemented asymmetric reach: `playerHitRadiusX = 0.42`, `playerHitFrontY = 0.50` (toward net), `playerHitBackY = 0.22` (behind), `playerHitZMin = 0.0`, `playerHitZMax = 0.95`.
  - Implemented identical asymmetric reach for the bot (`botHitFrontY = 0.50` toward net in $+Y$).
  - Updated `_drawHitbox` in both `PlayerVisualComponent` and `BotVisualComponent` to render the exact asymmetric boundaries, along with a middle waist-level depth ring for depth perception.
  - When the ball visually enters the debug box on screen, it is guaranteed to be inside `canPlayerHitBall()`.

---

## [2026-10-01 14:48:00 +08:00] - Gameplay Hit Physics & UX Improvements
- **Reason of Change**:
  - User requested:
    1. Removal of "MISSED!" text popup when swinging at air.
    2. Improved ball hitting consistency and reach.
    3. Reduction of side-out violations on bots and player for balls approaching on the side.
    4. Change button text from "Tap to Serve" to "Serve".
- **Cause of Error**:
  - `playerHitZMin` was set to `0.05`, causing balls right off the bounce ($Z \in [0.0, 0.05]$) to fail hit checks.
  - `ball.velocityX = (ball.x - playerX) * 0.12` pushed wide shots further outward into the bleachers.
- **Changes**:
  - Removed "MISSED!" feedback popup on empty swings in `lib/main.dart`.
  - Changed action button text to "SERVE".
  - Lowered `playerHitZMin` to `0.0` and raised `playerHitZMax` to `0.85`.
  - Added directional recovery physics clamping shot targets inside `[-courtWidth * 0.78, courtWidth * 0.78]`.
