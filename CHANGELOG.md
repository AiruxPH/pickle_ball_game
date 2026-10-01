# Changelog

All notable changes, fixes, and improvements to the Pickleball Game are documented here. This serves as persistent memory for the codebase.

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
