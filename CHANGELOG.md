# Changelog

All notable changes, fixes, and improvements to the Pickleball Game are documented here. This serves as persistent memory for the codebase.

---

## [2026-10-02] - Distinct Paddle Designs & Kinetic Familiar Identities

### Changes
- Added a data-driven `PaddleDesign` identity to every paddle in the catalog.
- Gave all seven paddles distinct familiar silhouettes instead of relying on color swaps: tournament balanced, lightning elongated, inferno wide-body, sovereign narrow/angular, cosmos rounded, industrial heavy/wide, and phantom extra-long/slender.
- Added paddle-specific face motifs shared conceptually by the 2D familiar and 3D inspector, including lightning, flame, crown, orbital, armored, and spectral treatments.
- Added unique familiar idle movement profiles, from Thunderstrike's quick electrical jitter to Starcaller's slow celestial drift and Kinetic Slammer's heavy mechanical pulse.
- Updated the 3D mesh renderer to vary head proportions and procedural surface accents from the same `PaddleDesign` data used by gameplay.
- Renamed the preview controls to `VIEW KINETIC FAMILIAR` and `VIEW 3D PADDLE` for clearer player-facing language.
- Added a catalog regression test ensuring every current paddle has a unique design identity and ID.
- Fixed hot-reload compatibility for pre-existing `PaddleItem` instances by resolving a safe tournament design fallback when the newly added design field is absent.
- Fixed invalid infinite-width `CustomPaint` constraints in both the 2D familiar and 3D mesh viewers by filling their bounded preview stacks with `Positioned.fill`.

### Files Changed
- `lib/models/paddle_item.dart`
- `lib/components/draw_kinetic_paddle.dart`
- `lib/components/player_visual_component.dart`
- `lib/components/bot_visual_component.dart`
- `lib/widgets/paddle_3d_preview.dart`
- `lib/widgets/interactive_racket_mesh_view.dart`
- `lib/widgets/racket_3d_painter.dart`
- `test/widget_test.dart`
- `CHANGELOG.md`

---

## [2026-10-02 20:54:00 +08:00] - Official USAP Rulebook Audit, Net Height Curvature & In-Game Guidebook Viewer

### 1. Root Cause Analysis & Fixes
- **`CourtDiagramWidget` 87.0px Horizontal Overflow**:
  - *Cause of Error*: The title header row `'USAP REGULATION COURT'` inside the interactive court blueprint column had unconstrained width within a 320px column. With container padding and canvas drawing dimensions, the remaining width for labels was ~182.7px, causing an 87px RenderFlex overflow exception.
  - *Fix Applied*: Wrapped title and dimension labels in `Expanded` and `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` with tightened letter spacing, eliminating layout overflows.
- **Rulebook Top Bar Overflow**:
  - *Cause of Error*: In `RulebookScreen`, the top header row contained an unconstrained `Column` alongside a fixed 250px search bar, causing overflow on compact and standard test viewports.
  - *Fix Applied*: Replaced `Spacer` and unconstrained Column with `Expanded(child: Column(...))` and wrapped `RulebookSearchBar` in `ConstrainedBox(constraints: BoxConstraints(maxWidth: 220, minWidth: 140))`.
- **Glossary Category Filtering Test Failure**:
  - *Cause of Error*: In `RulebookScreen`, the filter condition `if (_selectedCategory != null && _selectedCategory != RuleCategory.glossary && rule.category != _selectedCategory)` evaluated to false when `_selectedCategory == RuleCategory.glossary`. This caused all 15 rules to pass the filter, rendering 15 rule cards above the glossary terms in the ListView and pushing glossary cards out of the visible test viewport.
  - *Fix Applied*: Added an explicit check `if (_selectedCategory == RuleCategory.glossary) return false;` to exclude rules when the Glossary category is selected, placing glossary terms directly at the top of the list.
- **Duplicate Text Widget Finder in Live Search Test**:
  - *Cause of Error*: `find.text('Erne')` matched both the `EditableText` inside the search query input and the `Text` widget on the resulting `GlossaryCardWidget`.
  - *Fix Applied*: Targeted the glossary item specifically using `find.widgetWithText(GlossaryCardWidget, 'Erne')`.

### 2. Sliced Modular Architecture (Rule 2 Compliance)
- Extracted and sliced rulebook features into dedicated single-responsibility files:
  - `lib/models/usap_rule_models.dart`: Defines `RuleCategory`, `UsapRuleItem`, and `GlossaryTerm` data structures.
  - `lib/data/usap_rulebook_data.dart`: Comprehensive repository of official USA Pickleball rules, official citations, key takeaways, and glossary terms.
  - `lib/widgets/rulebook/court_diagram_painter.dart`: CustomPainter rendering the authentic 2D regulation court blueprint with NVZ, centerline, and service courts.
  - `lib/widgets/rulebook/court_diagram_widget.dart`: Interactive court blueprint widget with interactive zone highlight toggles (Kitchen, Right Service, Left Service, Baselines).
  - `lib/widgets/rulebook/rule_card_widget.dart`: Expandable cyberpunk rule card with official USAP citation badge, summary, full explanation, and pro key takeaway callout.
  - `lib/widgets/rulebook/rule_category_pill.dart`: Sliced horizontal category button with icons and active neon glow.
  - `lib/widgets/rulebook/rulebook_search_bar.dart`: Sliced search bar for real-time keyword filtering.
  - `lib/widgets/rulebook/glossary_card_widget.dart`: Card widget rendering official pickleball terminology definitions.
  - `lib/screens/rulebook_screen.dart`: Main screen assembling category filtering, court diagram, rule cards, and live search.

### 3. Official USAP Rulebook Audit & Alignment
- **Net Height Regulation Curvature (USAP Rule 2.C.2)**:
  - Aligned net geometry with official specifications: 36 inches (0.1364 normalized) at the sidelines and 34 inches (0.1288 normalized) at the center.
  - Added `PickleballRules.netHeightPosts`, `PickleballRules.netHeightCenter`, and `PickleballRules.netHeightAtX(double x)` calculating accurate catenary elevation across the net plane.
  - Updated `GameSimulation` to verify net crossing collisions against `netHeightAtX(ball.x)`.
- **In-Game Accessibility**:
  - Linked `RulebookScreen` from the `MainMenuScreen` top bar (`Icons.menu_book`).
  - Added `RULEBOOK` button to `GamePauseOverlay` allowing players to look up rules without leaving active matches.

### 4. Verification
- `dart analyze`: 0 issues found across all workspace files.
- `flutter test`: 48/48 tests passed (100%), including net height curvature verification, rulebook data completeness, and full `RulebookScreen` widget interaction flows.

---

## [2026-10-02 20:30:00 +08:00] - Two-Tap Serve Rhythm Mechanic, Legal Serve Box Highlight, & Penalty-Free Do-Overs

### 1. Root Cause Analysis & Fixes
- **`ServeRhythmMeter` 38.0px Right Overflow**:
  - *Cause of Error*: In `ServeRhythmMeter`, the header `Row` containing `'HIT SWEET SPOT!'` (with letter spacing 1.2) and `'TIMING'` had unconstrained widths within a fixed 220px container (`~189px` inner content width). When font metrics or test canvas constraints were applied, the text exceeded available horizontal space, causing a RenderFlex layout assertion exception.
  - *Fix Applied*: Increased outer container width to `240 * scale`, reduced padding, and wrapped the title text in `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))` with tighter letter spacing (`0.8`), ensuring zero overflow across all aspect ratios.
- **Widget Test Serve Strike Whiffing**:
  - *Cause of Error*: In `testWidgets('renders the pickleball game controls')`, the test tapped `TOSS` and immediately tapped `STRIKE!` in the next pump without simulated game time. Because 0ms had elapsed, `serveRhythm.progress` was 0.0 (< 0.35 threshold), triggering a timing whiff that reset the serve to `idle` instead of hitting into play.
  - *Fix Applied*: Added `await tester.pump(const Duration(milliseconds: 650));` between the toss and strike taps, letting the simulated toss rise smoothly into the sweet spot window for a clean serve strike into play.

### 2. Sliced Modular Architecture (Rule 2 Compliance)
- Sliced standalone logic and components into dedicated single-responsibility files:
  - `lib/simulation/serve_rhythm_state.dart`: Defines `ServeRhythmPhase` (`idle`, `tossing`, `struck`) and `ServeTimingResult` (`perfect`, `good`, `early`, `late`, `whiffEarly`, `whiffLate`, `timeout`) with feedback messages, power multipliers, and shot qualities.
  - `lib/simulation/serve_rhythm_controller.dart`: Standalone controller tracking toss progression, calculating parabolic arc height (`ballTossZ = 4 * 0.45 * progress * (1 - progress)`), evaluating strike timing, and managing do-over resets.
  - `lib/widgets/serve_rhythm_meter.dart`: Cyberpunk arcade HUD timing meter featuring neon track, wide good-timing zone, cyan sweet spot, and animated needle.
  - `lib/components/draw_serve_box_highlight.dart`: Standalone rendering helper computing and painting the glowing legal diagonal service box on the opponent's court per official USAPA pickleball regulation boundaries.

### 3. Gameplay Mechanics & Visual Features
- **Two-Tap Serve Rhythm System**:
  - First tap (`TOSS`): Tosses the pickleball vertically in a physics-based arc, transitioning the hit button to a pulsing cyan `STRIKE!` state.
  - Second tap (`STRIKE!`): Strikes the ball during its descent/apex. Timing directly governs ball velocity, angle accuracy, and shot quality.
  - Sweet spot contact generates `PERFECT SERVE!` with 1.15x speed multiplier and gold sparks.
  - Good contact generates `GOOD SERVE` with 1.0x baseline power.
  - Early/late contact generates reduced power serves (0.85x).
- **Penalty-Free Serve Do-Overs**:
  - If the player completely whiffs the strike (striking too early/too late, or letting the ball drop without striking), the simulation displays `DO OVER!` and resets the serve without any side-out penalty or score change.
- **Regulation Legal Serve Box Court Highlight**:
  - The opponent's diagonal service box is illuminated on court with a neon cyan boundary, corner crosshairs, and a subtle glowing fill, clearly indicating the target zone for legal serves.

### 4. Verification
- `dart analyze`: 0 issues found across the entire workspace.
- `flutter test`: 45/45 tests passed (100%), including dedicated unit tests for `ServeRhythmController`, `GameSimulation` two-tap toss/strike, penalty-free whiff resets, and `ServeRhythmMeter` rendering.

---

## [2026-10-02 19:54:00 +08:00] - Comprehensive Responsive Layout Architecture & Sliced UI Overlays

### 1. Root Cause Analysis of Layout Overflows
- **Pause Menu 27.0px Bottom Overflow**:
  - *Cause of Error*: `GamePauseOverlay` content had a fixed vertical footprint (~296px including 56px outer padding, 32px title, 28px margin, three 48px action buttons, and 24px spacing). On short landscape viewports (screen height ~260px - 320px), the `Column` inside `AngularFrame` exceeded the available screen height by 27px, causing a Flutter layout assertion exception with yellow/black hazard bars.
- **Paddle Shop Cards 7.0px Bottom Overflow**:
  - *Cause of Error*: On compact heights (`height < 520px`), `PaddleShopScreen` hardcoded carousel container height to 95px. `PaddleCarouselCard` had 28px vertical padding, 17px rarity badge, 28px title/tagline, 14px palette row, and flex spacing summing to ~102px, overflowing by 7px.
- **Top-Down Camera Scoreboard Collision**:
  - *Cause of Error*: In `CameraMode.topDown`, the camera eye was placed at `(0, 0, 2.15)`. At this zoom level, the top baseline and top bot's head were located at screen coordinates overlapping directly beneath the top centered scoreboard (`RALLY 20`).

### 2. Sliced Modular Architecture (Rule 2 Compliance)
- Extracted and sliced standalone widgets into individual files:
  - `lib/widgets/pause_menu_button.dart`: Standalone responsive action button widget with compact mode support, customizable colors, and icons.
  - `lib/widgets/confirmation_dialog.dart`: Standalone modal dialog with responsive sizing and `FittedBox` scale-down protection for destructive actions (Restart / Quit).
  - `lib/widgets/game_pause_overlay.dart`: Refactored to import and coordinate the sliced components cleanly.

### 3. Responsive Screen Improvements
- **`lib/widgets/game_pause_overlay.dart`**:
  - Added responsive padding, typography, and spacing adapting to `isCompact` (< 420px) and `isSuperCompact` (< 320px).
  - Wrapped `AngularFrame` in `FittedBox(fit: BoxFit.scaleDown)` ensuring that on any screen size or aspect ratio, the pause menu automatically and smoothly scales down without ever overflowing.
- **`lib/widgets/match_complete_overlay.dart`**:
  - Added responsive compact metrics and `FittedBox(fit: BoxFit.scaleDown)` wrapper to prevent similar victory/defeat dialog overflows on compact landscape windows.
- **`lib/widgets/paddle_carousel_card.dart`**:
  - Reduced vertical padding from 14px to 8px.
  - Wrapped inner card elements in `LayoutBuilder`, `FittedBox(fit: BoxFit.scaleDown)`, and `ConstrainedBox`, mathematically eliminating card overflows regardless of carousel height.
- **`lib/screens/paddle_shop_screen.dart`**:
  - Adjusted carousel height calculation to `(size.height * 0.28).clamp(104.0, 126.0)`.
- **`lib/game_simulation.dart`**:
  - Adjusted `CameraMode.topDown` camera parameters to `eye: (shakeX, shakeY - 0.12, 2.65)` and `target: (0.0, -0.12, 0.0)`. The court now has generous margins and the top bot has clear breathing room below the scoreboard.
- **`lib/screens/game_screen.dart`**:
  - Lowered minimum clamp for `_uiScale` to `0.55` so controls and HUD elements scale proportionally on compact mobile displays.

### 4. Verification
- `dart analyze`: 0 issues found across all files.
- `flutter test`: 41/41 tests passed (100%), including new dedicated compact landscape tests for `GamePauseOverlay`, `MatchCompleteOverlay`, and `PaddleShopScreen`.

---

## [2026-10-02 18:29:00 +08:00] - Mouse Wheel & Pointer Scroll Carousel Navigation in Paddle Shop

### 1. Mouse Wheel Navigation in Horizontal Carousel
- **Reason of Change**:
  - Enable desktop users to scroll the paddle list with their mouse wheel.
  - Scrolling the mouse wheel down shifts the list to the left (revealing the next paddle on the right).
  - Scrolling the mouse wheel up shifts the list to the right (revealing the previous paddle on the left).
  - Enable mouse click-and-drag navigation across the carousel.
- **Changes**:
  - `lib/screens/paddle_shop_screen.dart`:
    - Added `_handlePointerScroll(PointerScrollEvent event)` with ~160ms throttle to translate vertical mouse wheel notches (`scrollDelta.dy`) and horizontal wheel tilts (`scrollDelta.dx`) into responsive single-card carousel steps.
    - Wrapped lower deck carousel in a translucent `Listener` intercepting `PointerScrollEvent`.
    - Added `ScrollConfiguration` enabling `PointerDeviceKind.mouse` and `PointerDeviceKind.trackpad` drag interactions on `PageView.builder`.
- **Verification**:
  - `dart analyze`: 0 issues found.
  - `flutter test`: 38/38 tests passed.

---

## [2026-10-02 18:18:00 +08:00] - AI Bot Dynamic Paddle Equipment & Hit VFX in Bot vs Bot Matches

### 1. Bot VFX & Paddle Display Diagnostics
- **Cause of Error**:
  - `spawnHitEffect` in `PickleballFlameGame` was previously hardcoded to `SettingsManager().equippedPaddleId`, which strictly referenced the local human player's equipped paddle.
  - In `PickleballFlameGame`'s simulation event loop, `case GameplayEventType.botHit:` triggered swing timers and camera shake, but completely omitted calling `spawnHitEffect`.
  - In `BotVisualComponent`, the enemy bot's familiar paddle colors were hardcoded to fixed crimson values (`0xFFFF1744`), ignoring the paddle catalog.
  - In `PlayerVisualComponent`, the bottom character also defaulted to `SettingsManager().equippedPaddleId` even during `GameMode.botVsBot` spectator matches.
  - Consequently, bots never triggered pixel-art hit VFX, and bot vs bot matches showed zero paddle effects.
- **Reason of Change**:
  - Allow AI bots to randomly equip different tournament and elemental paddles per game.
  - Ensure all bots (enemy bot and bottom bot in Bot vs Bot) trigger their equipped paddle's pixel-art impact VFX on hits and smashes.
  - Render each bot's floating kinetic familiar paddle with their equipped skin colors.

### 2. Implementation & Sliced Architecture
- **Changes**:
  - `lib/models/paddle_item.dart`:
    - Added `PaddleCatalog.getRandomPaddle([Random? random])` to pick a random paddle from the available catalog.
  - `lib/pickleball_flame_game.dart`:
    - Added `topBotPaddle` and `bottomBotPaddle` state fields.
    - Implemented `randomizeBotPaddles([Random? random])` to assign distinct random paddles to both bots.
    - Updated `spawnHitEffect({required bool isSmash, PaddleItem? paddle})` to accept an optional paddle parameter, defaulting to the player's equipped paddle.
    - In the simulation event loop, wired `case GameplayEventType.botHit:` to spawn hit VFX using `topBotPaddle` (for enemy/top bot) or `bottomBotPaddle` (for player-side bot in Bot vs Bot).
  - `lib/components/bot_visual_component.dart`:
    - Updated `drawBotFamiliarPaddle` to bind face, rim, energy, and sweet-spot colors to `game.topBotPaddle`.
  - `lib/components/player_visual_component.dart`:
    - Updated `drawPlayerFamiliarPaddle` to bind to `game.bottomBotPaddle` when `game.simulation.gameMode == GameMode.botVsBot`.
  - `lib/screens/game_screen.dart`:
    - Hooked `flameGame.randomizeBotPaddles()` into `_startGame()`, guaranteeing a fresh random paddle selection for bots every game and match restart.

### 3. Verification
- `dart analyze`: 0 issues found.
- `flutter test`: 38/38 tests passed.

---

## [2026-10-02 17:15:00 +08:00] - Hardware-Accelerated 3D Racket Mesh Renderer & Cross-Platform Windows Fix

### 1. 3D Model Display Failure Diagnostics
- **Cause of Error**:
  - `model_viewer_plus` relies on `webview_flutter`, which only supports Android, iOS, and Web; it lacks a native Windows Desktop implementation out of the box, throwing platform unimplemented errors.
  - Furthermore, `Paddle3DPreview` contained a platform filter that defaulted to the 2D familiar canvas on Windows (`_prefer3dModel = kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS`).
  - As a result, users running on Windows Desktop could not view the 3D mesh.
- **Reason of Change**:
  - Provide a 100% native, zero-dependency, hardware-accelerated 3D mesh rasterizer in pure Flutter that renders the actual 3D geometry of `racket_for_pickleball.glb` across all platforms (Windows, macOS, Linux, Android, iOS, Web) at high framerates without requiring external WebViews.

### 2. Standalone Architecture & 3D Engine Implementation
- **Changes**:
  - `assets/models/racket_mesh.bin`:
    - Extracted and normalized the 3D vertices, surface normals, and triangle indices directly from `assets/models/racket_for_pickleball.glb` into an optimized 231 KB binary mesh containing 3 distinct parts:
      1. **Blade / Face** (6,188 vertices, 28,740 indices)
      2. **Grip Wrap** (611 vertices, 1,524 indices)
      3. **Rim & Butt Cap** (433 vertices, 1,332 indices)
  - `lib/services/racket_3d_mesh_loader.dart`:
    - Standalone loader that parses `racket_mesh.bin` via `rootBundle.load` and caches the structured mesh in memory in under 2 milliseconds.
  - `lib/widgets/racket_3d_painter.dart`:
    - Hardware-accelerated `CustomPainter` rendering 3D triangles via `canvas.drawVertices`:
      - 3D perspective projection with depth scaling.
      - 3D Blinn-Phong lighting model calculating diffuse light ($\mathbf{N} \cdot \mathbf{L}$) and specular highlights $(\mathbf{N} \cdot \mathbf{H})^{s}$.
      - Dynamic per-paddle skinning: maps the blade face, carbon fiber core, edge guard, and sweet spot directly to each paddle's cosmetic colors (`paddleFaceColor`, `paddleRimColor`, `sweetSpotColor`).
      - Soft floor contact shadow and energy glow.
  - `lib/widgets/interactive_racket_mesh_view.dart`:
    - Interactive 3D container supporting:
      - 360° horizontal drag rotation (yaw).
      - Vertical drag tilt (pitch).
      - Continuous smooth auto-rotation with automatic resumption after user interaction.
      - Reset view action button and interactive drag helper badge.
  - `lib/widgets/paddle_3d_preview.dart`:
    - Refactored to display `InteractiveRacketMeshView` by default on all platforms, eliminating WebView failures, with an optional toggle to the 2D orbital familiar canvas.

### 3. Verification
- `dart analyze`: 0 issues found.
- `flutter test`: All 38 tests passed.

---

## [2026-10-02 16:50:00 +08:00] - Paddle Shop with 3D Carousel Viewer, Interactive GLB Racket, and Pixel-Art Hit VFX

### 1. Carousel-Type Paddle Shop Architecture
- **Reason of Change**:
  - Introduce an equipment shop allowing players to view, compare, inspect, and equip different tournament and elemental paddles.
  - Implement a tactile, carousel-type viewer (`PageView.builder`) with perspective card scaling, smooth indicator dots, rarity badging, and spec bars.
- **Changes**:
  - `lib/models/paddle_item.dart`:
    - Defined `PaddleItem` data model holding rarity (`standard`, `rare`, `epic`, `legendary`), visual color themes (`paddleFaceColor`, `paddleRimColor`, `energyColor`, `sweetSpotColor`), pixel-art VFX spritesheet specifications, and gameplay ratings (`power`, `control`, `spin`).
    - Created `PaddleCatalog` with 7 distinct paddles:
      1. **Pro Tournament** (Standard USAP Graphite Core)
      2. **Thunderstrike** (Overcharged Lightning Core with electric arc VFX)
      3. **Inferno Blaze** (Thermobaric Fireburst Face with fireball burst VFX)
      4. **Blood Sovereign** (Occult Sanguine Resonance with dark blood-void VFX)
      5. **Starcaller Cosmos** (Astral Supernova Weave with lavender supernova VFX)
      6. **Kinetic Slammer** (High-Impact Alloy with concentric shockwave VFX)
      7. **Shadow Phantom** (Sub-Zero Stealth Composite with smoke dissipation VFX)
  - `lib/widgets/paddle_carousel_card.dart`:
    - Standalone carousel card widget with smooth active-scale transitions, glassmorphic styling, glowing borders matching paddle energy colors, rarity badges, and instant "EQUIP" / "EQUIPPED" actions.
  - `lib/widgets/paddle_stats_panel.dart`:
    - Standalone specifications panel displaying animated rating progress bars (`POWER`, `CONTROL`, `SPIN`) and lore descriptions.
  - `lib/screens/paddle_shop_screen.dart`:
    - Standalone carousel shop screen with top navigation, live equipped status, active page indicator pills, and animated card transitions.
  - `lib/screens/main_menu_screen.dart`:
    - Added dedicated "SHOP" button in the top action bar with cyan shopping-bag icon and active navigation route.

### 2. 3D GLB Racket & Real-Time Kinetic Canvas Preview
- **Reason of Change**:
  - Leverage the 3D model asset `assets/models/racket_for_pickleball.glb` while ensuring robust cross-platform fallback for environments without WebGL/WebView2.
- **Changes**:
  - `lib/widgets/paddle_3d_preview.dart`:
    - Embedded `ModelViewer` targeting `assets/models/racket_for_pickleball.glb` with auto-rotation, camera controls, and transparent canvas.
    - Integrated interactive fallback / manual toggle to a real-time `CustomPaint` kinetic familiar paddle canvas rendering orbit trails, carbon weave texture, and glowing sweet spots.

### 3. Pixel-Art Animated VFX Integration
- **Reason of Change**:
  - Bring visual excitement to hits and smashes using newly imported pixel-art VFX sprite packs (Lightning, Fire, Blood, Starcaller, Impacts, Smoke).
- **Changes**:
  - Processed and registered spritesheets in `assets/images/vfx/` and updated `pubspec.yaml`.
  - `lib/components/animated_vfx_component.dart`:
    - Flame component that loads and animates sprite sheet frames with pixel-perfect filtering (`FilterQuality.none`), automatic frame duration timing, and alpha fadeout.
  - `lib/pickleball_flame_game.dart`:
    - Updated `spawnHitEffect` to spawn `AnimatedVfxComponent` at the ball's projected 3D coordinates when the equipped paddle has an associated VFX asset.
  - `lib/components/player_visual_component.dart`:
    - Bound kinetic familiar paddle rendering to the player's currently equipped paddle colors (`SettingsManager().equippedPaddleId`).

### 4. Standalone Modular Slicing Rule Compliance
- **Reason of Change**:
  - Adhere to the strict architectural rule: every new component and widget must reside in its own dedicated, standalone file to prevent file bloat.
- **Verification**:
  - `dart analyze`: 0 warnings, 0 errors.
  - `flutter test`: 38/38 tests passing.

---

## [2026-10-02 16:15:00 +08:00] - Monolith Codebase Slicing: Modularization of Main Application and Flame Game Components

### 1. Main Entrypoint & UI Overlay Deconstruction
- **Reason of Change**:
  - `lib/main.dart` previously contained 1,397 lines combining bootstrap initialization, the main match screen (`PickleballGame`), referee popups, joystick controls, pause overlay dialogs, match complete overlays, and sandbox debug controls.
  - Slicing these into dedicated standalone files improves AI code editing precision, minimizes context consumption, and prevents regressions.
- **Changes**:
  - `lib/main.dart`: Slimmed down from 1,397 lines to 43 lines, serving solely as the Flutter and Firebase bootstrap entrypoint, re-exporting `PickleballGame` for 100% backward compatibility.
  - `lib/screens/game_screen.dart`: Extracted the `PickleballGame` stateful screen hosting the 3D Flame simulation canvas and assembling UI overlays.
  - `lib/widgets/referee_popup_widget.dart`: Extracted the referee call banner and animated popup state.
  - `lib/widgets/game_debug_panel.dart`: Extracted the sandbox debug controls panel for toggling hitboxes, freezing AI, and altering game speed.
  - `lib/widgets/game_pause_overlay.dart`: Extracted `GamePauseOverlay`, `PauseMenuButton`, and `ConfirmationDialog`.
  - `lib/widgets/match_complete_overlay.dart`: Extracted `MatchCompleteOverlay` displaying victory/defeat banners and match navigation buttons.
  - `lib/widgets/game_controls_overlay.dart`: Extracted `VirtualJoystickWidget`, `HitButtonWidget`, `DashButtonWidget`, `CameraButtonWidget`, and `AltitudeSliderWidget`.
  - `lib/widgets/spectator_stats_overlay.dart`: Extracted spectator live telemetry and bot status cards.

### 2. Flame Game Visual Component & Effect Slicing
- **Reason of Change**:
  - `lib/pickleball_flame_game.dart` previously contained 2,119 lines combining the core `PickleballFlameGame` game loop with 8 visual and VFX components, along with a 300+ line kinetic paddle renderer.
- **Changes**:
  - `lib/components/draw_kinetic_paddle.dart`: Extracted the standalone top-level `drawKineticPaddle` rendering function for drawing the elongated familiar paddle, elliptical orbit, aim vector, and impact shockwaves.
  - `lib/components/ball_visual_component.dart`: Extracted `BallVisualComponent` for 3D ball projection, shadows, and velocity trails.
  - `lib/components/bot_visual_component.dart`: Extracted `BotVisualComponent` for bot character animation, opponent aura tint, and reach hitboxes.
  - `lib/components/player_visual_component.dart`: Extracted `PlayerVisualComponent` for player character animation, electric cyan aura, and hitboxes.
  - `lib/components/court_visual_component.dart`: Extracted `CourtVisualComponent` for tournament stadium, practice facility, cloth net physics, grandstands, and serve trajectory arcs.
  - `lib/components/hit_effect_component.dart`: Extracted `HitEffectComponent` for hit/smash shockwaves.
  - `lib/components/bounce_effect_component.dart`: Extracted `BounceEffectComponent` for ball floor bounce ripples.
  - `lib/components/dash_effect_component.dart`: Extracted `DashEffectComponent` for dash VFX rings and speed streaks.
  - `lib/pickleball_flame_game.dart`: Slimmed down to 232 lines focused solely on game loop orchestration and component registration, re-exporting all components.

### 3. Diagnostics & Error Resolution
- **Cause of Error**:
  - During static analysis of `lib/components/court_visual_component.dart`, `MatchSide` was undefined because `match_state.dart` had not been explicitly imported into the standalone component file.
  - `bot_visual_component.dart` and `player_visual_component.dart` had redundant imports for `draw_kinetic_paddle.dart` already exposed by `pickleball_flame_game.dart`.
- **Resolution**:
  - Added `import '../match_state.dart';` to `court_visual_component.dart`.
  - Removed redundant import directives in bot and player visual components.
  - Verified with `dart analyze` (0 issues) and `flutter test` (all 38 tests passed).

---

## [2026-10-01 20:42:00 +08:00] - Orbital Familiar Paddle: Dynamic 3D Revolution Around Player & Bot Characters

### 1. Familiar Orbital Motion & Depth-Aware Layering
- **Reason of Change**:
  - Transform the floating kinetic paddle into a magical, high-tech familiar companion that actively revolves around the player and bot characters in a smooth 3D elliptical orbit when moving or idle, and darts dynamically forward to strike incoming balls.
- **Changes**:
  - In `lib/pickleball_flame_game.dart` (`_drawKineticPaddle`):
    - **Continuous Elliptical Orbit**:
      - Configured orbit with $\omega = 2.6\text{ rad/s}$ (~2.4s per revolution).
      - Ellipse dimensions: $R_x = 28 \times \text{scale}$, $R_y = 11.5 \times \text{scale}$ (perspective compression), hovering at chest/torso height ($Y = -12 \times \text{scale}$) with vertical floating bob.
    - **Aerodynamic Familiar Lean**:
      - Dynamically tilted the paddle body along its orbital tangent velocity ($\text{tilt} = -\sin(\theta) \times 0.25$), giving it the posture of an autonomous drone gliding along its trajectory.
    - **3D Depth Scaling & Layering**:
      - Modulated paddle scale by depth ($\text{depthScale} = 1.0 + \sin(\theta) \times 0.12$), making it slightly larger in front and smaller behind.
      - In `PlayerVisualComponent` and `BotVisualComponent`, evaluated $\sin(\theta) < -0.15$: when passing behind, the familiar renders behind the character sprite; when passing in front, it renders on top.
    - **Visual Familiar Aesthetics**:
      - Rendered an ethereal orbital waist ring tracing the familiar's elliptical path.
      - Added 3-tiered glowing stardust motion tail motes trailing behind the paddle in orbit.
    - **Seamless Strike Transition**:
      - On swing, the familiar launches smoothly from its instantaneous orbital coordinates to the ball impact point, aligning its sweet spot on contact, and returns fluidly into its orbital path on swing completion.

---

## [2026-10-01 20:35:00 +08:00] - Shrink Player & Bot Hitboxes, Eliminate Unrealistic Midair Hits, and Elongate Paddle for Precise Visual Contact

### 1. Reduce Hitbox Dimensions to Authentic Physical Reach
- **Cause of Error**:
  - The previous hitboxes were oversized (`radiusX = 0.35`, `frontY = 0.32`, `backY = 0.32`, `zMax = 0.85`). With the court half-width being only $0.44$ and regulation net height only $0.1364$, a $Z = 0.85$ limit allowed bots and players to strike balls floating more than $6\times$ net height in the sky ("hitting midair in thin air"), while the wide radius allowed hitting balls without standing anywhere near them.
- **Reason of Change**:
  - Shrink the hitboxes down to realistic physical reach limits for competitive play, eliminating unrealistic midair floating strikes.
- **Changes**:
  - In `lib/game_simulation.dart`:
    - `playerHitRadiusX` & `botHitRadiusX`: reduced from $0.35$ to $0.26$ (~26% reduction).
    - `playerHitFrontY` & `botHitFrontY`: reduced from $0.32$ to $0.24$ (25% reduction).
    - `playerHitBackY` & `botHitBackY`: reduced from $0.32$ to $0.18$ (44% reduction, preventing hitting balls deep behind the back).
    - `playerHitZMax` & `botHitZMax`: reduced from $0.85$ to $0.52$ (39% reduction, strictly bounding overhead reach to realistic smash arcs while eliminating strikes in the upper stratosphere).

### 2. Elongated Pro Paddle Visuals & Precise Ball Strike Alignment
- **Cause of Error**:
  - The previous visual paddle was stubby ($29 \times \text{scale}$ total length) and used arbitrary rotational spin during swings (`paddleAngle = baseAngle + (flightCurve * 2.8) + (aimAngle * 0.3)`), causing the blade to point away from the ball during contact so it looked like hitting the ball without physically touching it.
- **Reason of Change**:
  - Enlarge and elongate the paddle to professional tournament proportions (matching models like Joola Perseus / Selkirk Vanguard) and orient its sweet spot directly onto the ball at the moment of strike.
- **Changes**:
  - In `_drawKineticPaddle` (`lib/pickleball_flame_game.dart`):
    - **Elongated Blade**: Extended blade height from $20 \times \text{scale}$ to $31 \times \text{scale}$ and width to $15 \times \text{scale}$ with aerodynamic rounded corners.
    - **Pro Handle & Grip**: Extended handle length from $12 \times \text{scale}$ to $15 \times \text{scale}$ with dark graphite core, 4-tier perforated white grip tape wraps, beveled octagonal butt cap, and tapered neck collar.
    - **Total Paddle Length**: Increased from $29 \times \text{scale}$ to $50.8 \times \text{scale}$ (~75% longer).
    - **Face Details**: Added carbon fiber micro-texture stripes, concentric sweet spot rings, and aerodynamic speed chevrons.
    - **Kinetic Strike Alignment**:
      - Calculated exact strike orientation: `strikeAngle = aimAngle + math.pi / 2`, aligning the elongated blade face along the vector to the ball.
      - Smoothly blended from hover angle through contact into follow-through.
      - Positioned the paddle sweet spot ($19 \times \text{scale}$ along blade) directly onto `ballScreenPos`, producing crisp, visible contact on the paddle face.
      - Centered contact shockwave burst on the sweet spot.

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
