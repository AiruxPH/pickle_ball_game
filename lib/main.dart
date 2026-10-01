import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'game_debug_config.dart';
import 'game_input_adapter.dart';
import 'game_simulation.dart';
import 'match_state.dart';
import 'pickleball_flame_game.dart';
import 'screens/loading_screen.dart';
import 'settings_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/angular_frame.dart';
import 'widgets/match_hud.dart';
import 'widgets/practice_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsManager().init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Use the full landscape display on mobile. SafeArea still keeps interactive
  // UI clear of notches, camera cutouts, and rounded corners.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoadingScreen(),
    ),
  );
}

class PickleballGame extends StatefulWidget {
  final int gameMode; // 0 = PlayerVsBot, 1 = BotVsBot
  final BotDifficulty botDifficulty;
  const PickleballGame({
    super.key,
    this.gameMode = 0,
    this.botDifficulty = BotDifficulty.normal,
  });

  @override
  State<PickleballGame> createState() => _PickleballGameState();
}

class _PickleballGameState extends State<PickleballGame> {
  final FocusNode _focusNode = FocusNode();
  final MatchState match = MatchState();
  final GameInputAdapter _input = GameInputAdapter();
  late final PickleballFlameGame flameGame;

  _PickleballGameState();

  GameSimulation get simulation => flameGame.simulation;
  double get ballZ => simulation.ball.z;

  bool isPlaying = false;
  bool _isPaused = false;
  bool _showDebugMenu = false;
  String feedbackText = '';
  double _initialZoomZ = 4.0;

  int get playerScore => match.playerScore;
  int get botScore => match.botScore;
  double get _uiScale =>
      (MediaQuery.sizeOf(context).height / 600).clamp(0.68, 1.0);

  @override
  void initState() {
    super.initState();
    // Debug visualization is session-only and should never leak into a fresh
    // match or spectator broadcast.
    GameDebugConfig.showHitboxes = false;
    _showDebugMenu = false;
    GameMode mode = GameMode.playerVsBot;
    MapType map = MapType.stadium;
    if (widget.gameMode == 1) {
      mode = GameMode.botVsBot;
    } else if (widget.gameMode == 2) {
      mode = GameMode.freeRoamPractice;
      map = MapType.practiceFacility;
    }

    flameGame = PickleballFlameGame(
      simulation: GameSimulation(
        gameMode: mode,
        mapType: map,
        botDifficulty: widget.botDifficulty,
      ),
    );
    flameGame.onRallyEnd = _handleRallyEnd;
    flameGame.simulation.onPlayerDash = (x, y) {
      flameGame.spawnDashEffect(x: x, y: y, isPlayer: true);
    };
    flameGame.simulation.onPlayerHit = (isSmash) {
      if (!mounted) return;
      if (SettingsManager().hapticsEnabled) {
        if (isSmash) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        feedbackText = isSmash ? 'SMASH!' : 'GOOD HIT';
        flameGame.spawnHitEffect(isSmash: isSmash);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted &&
              (feedbackText == 'SMASH!' || feedbackText == 'GOOD HIT')) {
            setState(() => feedbackText = '');
          }
        });
      });
    };
    flameGame.simulation.onPracticeTargetHit = (targetName, points) {
      if (!mounted) return;
      if (SettingsManager().hapticsEnabled) {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        feedbackText = 'TARGET HIT! +$points';
        flameGame.spawnHitEffect(isSmash: true);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && feedbackText.startsWith('TARGET HIT!')) {
            setState(() => feedbackText = '');
          }
        });
      });
    };
    flameGame.simulation.onNetHit = () {
      if (!mounted) return;
      if (SettingsManager().hapticsEnabled) {
        HapticFeedback.lightImpact();
      }
      if (mode == GameMode.freeRoamPractice) {
        setState(() {
          feedbackText = 'NET FAULT!';
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted && feedbackText == 'NET FAULT!') {
              setState(() => feedbackText = '');
            }
          });
        });
      }
    };
    _input.onJoystickChanged = (x, y) {
      setState(() {
        flameGame.inputX = x;
        flameGame.inputY = y;
      });
    };
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _startGame();
    });
  }

  void _startGame() {
    setState(() {
      if (match.isComplete) match.reset();
      match.start();
      isPlaying = true;
      _isPaused = false;
      simulation.resetRally(
        servingSide: match.servingSide,
        serverScore: match.servingSide == MatchSide.player
            ? match.playerScore
            : match.botScore,
      );
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
    if (widget.gameMode == 2) {
      // In practice mode, continuous drills run without match score interruption
      return;
    }
    setState(() {
      final previousPlayerScore = playerScore;
      final previousBotScore = botScore;
      final pointWinner = rallyEnd == RallyEnd.playerFault
          ? MatchSide.bot
          : MatchSide.player;
      match.resolveRally(rallyWinner: pointWinner);
      if (match.isComplete) {
        feedbackText = playerScore > botScore ? 'YOU WIN!' : 'CPU WINS';
      } else if (playerScore > previousPlayerScore) {
        feedbackText = 'POINT FOR YOU!';
      } else if (botScore > previousBotScore) {
        feedbackText = 'POINT FOR CPU!';
      } else {
        feedbackText = 'SIDE OUT!';
      }

      if (!match.isComplete) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            if (feedbackText == 'POINT FOR YOU!' ||
                feedbackText == 'POINT FOR CPU!' ||
                feedbackText == 'SIDE OUT!') {
              setState(() => feedbackText = '');
            }
            setState(() {
              simulation.resetRally(
                servingSide: match.servingSide,
                serverScore: match.servingSide == MatchSide.player
                    ? match.playerScore
                    : match.botScore,
              );
            });
          }
        });
      } else {
        isPlaying = false;
      }

      _isPaused = false;
    });
  }

  void _executeSwing() {
    if (!isPlaying || _isPaused || widget.gameMode == 1) return;
    setState(() => flameGame.isSwinging = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => flameGame.isSwinging = false);
    });
    final swingResult = simulation.swing(
      joystickX: flameGame.effectiveInputX,
      joystickY: flameGame.effectiveInputY,
    );
    setState(() {
      if (swingResult == SwingResult.twoBounceFault) {
        feedbackText = 'TWO-BOUNCE FAULT!';
        if (widget.gameMode != 2) {
          _handleRallyEnd(RallyEnd.playerFault);
        } else {
          simulation.practiceStreak = 0;
        }
      } else if (swingResult == SwingResult.kitchenFault) {
        feedbackText = 'KITCHEN FAULT!';
        if (widget.gameMode != 2) {
          _handleRallyEnd(RallyEnd.playerFault);
        } else {
          simulation.practiceStreak = 0;
        }
      }
    });
  }

  void _showPracticeDrillDialog() {
    showDialog(
      context: context,
      builder: (context) => PracticeDrillsDialog(
        simulation: simulation,
        onDrillChanged: (drill) {
          setState(() {
            simulation.practiceDrill = drill;
          });
        },
        onIntervalChanged: (val) {
          setState(() {
            simulation.practiceFeedIntervalSeconds = val;
          });
        },
        onAutoFeedChanged: (val) {
          setState(() {
            simulation.practiceAutoFeed = val;
          });
        },
        onResetStats: () {
          setState(() {
            simulation.practiceStreak = 0;
            simulation.practiceScore = 0;
            simulation.practiceTargetHits = 0;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    flameGame.stop();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildDebugPanel() {
    return Positioned(
      top: 60,
      left: 8,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SANDBOX CONTROLS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Show Hitboxes',
                  style: TextStyle(color: Colors.white),
                ),
                value: GameDebugConfig.showHitboxes,
                onChanged: (val) =>
                    setState(() => GameDebugConfig.showHitboxes = val),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Freeze AI',
                  style: TextStyle(color: Colors.white),
                ),
                value: GameDebugConfig.freezeAI,
                onChanged: (val) =>
                    setState(() => GameDebugConfig.freezeAI = val),
              ),
              Text(
                'Speed: ${GameDebugConfig.gameSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                min: 0.0,
                max: 2.0,
                divisions: 20,
                value: GameDebugConfig.gameSpeed,
                onChanged: (val) =>
                    setState(() => GameDebugConfig.gameSpeed = val),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Bypass Kitchen Rules',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                value: GameDebugConfig.bypassKitchenRules,
                onChanged: (val) =>
                    setState(() => GameDebugConfig.bypassKitchenRules = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      match.playerScore = 10;
                      match.botScore = 10;
                      simulation.currentServerScore = 10;
                    });
                  },
                  child: const Text('Fast Forward (10-10)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space) {
            _executeSwing();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (isPlaying) _togglePause();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                  event.logicalKey == LogicalKeyboardKey.shiftRight)) {
            if (widget.gameMode != 1) {
              flameGame.simulation.dashPlayer();
            }
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyF &&
              widget.gameMode == 2) {
            flameGame.simulation.launchBallMachine();
            setState(() {});
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
              // 1. The Game rendering (centered with 9:16 aspect ratio)
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _initialZoomZ = simulation.camera.freeRoamZ;
                    },
                    onScaleUpdate: (details) {
                      if (simulation.camera.mode == CameraMode.freeRoam) {
                        if (details.scale != 1.0) {
                          simulation.camera.freeRoamZ =
                              (_initialZoomZ / details.scale).clamp(0.4, 2.8);
                        }
                        // Handle panning directly without triggering a Flutter rebuild.
                        // The Flame game loop will naturally pick up these changes.
                        simulation.camera.freeRoamYaw -=
                            details.focalPointDelta.dx * 0.01;
                        simulation.camera.freeRoamPitch -=
                            details.focalPointDelta.dy * 0.01;
                        simulation.camera.freeRoamPitch = simulation
                            .camera
                            .freeRoamPitch
                            .clamp(-math.pi / 2.2, math.pi / 6.0);
                      }
                    },
                    child: GameWidget(game: flameGame),
                  ),
                ),
              ),

              // 2. The full-screen UI overlay
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (isPlaying)
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                icon: Icon(
                                  _isPaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: _isPaused
                                    ? 'Resume game'
                                    : 'Pause game',
                                onPressed: _togglePause,
                              )
                            else
                              const SizedBox(width: 36),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: const Icon(
                                Icons.bug_report,
                                color: Colors.white70,
                                size: 22,
                              ),
                              tooltip: 'Debug menu',
                              onPressed: () => setState(
                                () => _showDebugMenu = !_showDebugMenu,
                              ),
                            ),
                            if (widget.gameMode != 2)
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: MatchScoreboard(
                                      leftLabel: widget.gameMode == 1
                                          ? 'TOP'
                                          : 'CPU',
                                      leftScore: botScore,
                                      leftColor: AppTheme.teamCpu,
                                      rightLabel: widget.gameMode == 1
                                          ? 'BOTTOM'
                                          : 'YOU',
                                      rightScore: playerScore,
                                      rightColor: AppTheme.teamPlayer,
                                      leftServing:
                                          match.servingSide == MatchSide.bot,
                                      rightServing:
                                          match.servingSide == MatchSide.player,
                                      rallyLength: simulation.rallyLength,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Center(
                                  child: PracticeHud(
                                    simulation: simulation,
                                    onLaunchBall: () {
                                      simulation.launchBallMachine();
                                      setState(() {});
                                    },
                                    onOpenDrillSettings:
                                        _showPracticeDrillDialog,
                                    onCycleDrill: () {
                                      setState(() {
                                        final drills = PracticeDrill.values;
                                        final nextIdx =
                                            (simulation.practiceDrill.index +
                                                1) %
                                            drills.length;
                                        simulation.practiceDrill =
                                            drills[nextIdx];
                                      });
                                    },
                                  ),
                                ),
                              ),
                            if (widget.gameMode != 2) const SizedBox(width: 36),
                          ],
                        ),
                        // Removed old feedbackText widget
                      ],
                    ),
                  ),
                ),
              ),
              if (feedbackText.isNotEmpty)
                Positioned(
                  bottom: 120 * _uiScale,
                  left: 16,
                  child: IgnorePointer(
                    child: RefereePopupWidget(text: feedbackText),
                  ),
                ),
              if (isPlaying &&
                  !_isPaused &&
                  (widget.gameMode == 0 || widget.gameMode == 2))
                Positioned(
                  bottom: 16 * _uiScale,
                  left: 14,
                  right: 14,
                  child: ListenableBuilder(
                    listenable: SettingsManager(),
                    builder: (context, child) {
                      final settings = SettingsManager();
                      final joystick = _buildJoystick();
                      final actionButtons = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDashButton(),
                          SizedBox(width: 16 * _uiScale),
                          _buildHitButton(),
                        ],
                      );

                      return Opacity(
                        opacity: settings.buttonOpacity,
                        child: Transform.scale(
                          scale: settings.buttonScale,
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: settings.isLeftHanded
                                ? [actionButtons, joystick]
                                : [joystick, actionButtons],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (isPlaying && !_isPaused && widget.gameMode == 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Transform.scale(
                    scale: _uiScale,
                    alignment: Alignment.topRight,
                    child: _buildSpectatorStatsOverlay(),
                  ),
                ),
              if (isPlaying && !_isPaused && widget.gameMode == 1)
                Positioned(
                  bottom: 16 * _uiScale,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (simulation.camera.mode == CameraMode.freeRoam)
                        _buildJoystick()
                      else
                        SizedBox(width: 80 * _uiScale, height: 80 * _uiScale),
                      Row(
                        children: [
                          if (simulation.camera.mode == CameraMode.freeRoam)
                            _buildAltitudeSlider(),
                          SizedBox(width: 16 * _uiScale),
                          _buildCameraButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_isPaused) _buildPauseOverlay(),
              if (match.isComplete) _buildMatchCompleteOverlay(),
              if (_showDebugMenu) _buildDebugPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoystick() {
    final scale = _uiScale;
    return Semantics(
      label: 'Move player',
      child: Listener(
        onPointerDown: (e) {
          _input.onPointerDown(e);
          setState(() {});
        },
        onPointerMove: (e) {
          _input.onPointerMove(e);
          setState(() {});
        },
        onPointerUp: (e) {
          _input.onPointerUp(e);
          setState(() {});
        },
        onPointerCancel: (e) {
          _input.onPointerCancel(e);
          setState(() {});
        },
        child: Container(
          width: 140 * scale,
          height: 140 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Transform.translate(
              offset: _input.knobOffset * scale,
              child: Container(
                width: 50 * scale,
                height: 50 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitButton() {
    final scale = _uiScale;
    final isPlayerServing =
        simulation.playPhase == MatchPlayPhase.waitingForServe &&
        simulation.servingSide == MatchSide.player;
    final buttonText = isPlayerServing ? 'SERVE' : 'HIT';
    final buttonColor = isPlayerServing
        ? const Color(0xFFFF6D00)
        : const Color(0xFFF59E0B);
    final textColor = isPlayerServing ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      label: isPlayerServing ? 'Serve the ball' : 'Hit the ball',
      child: GestureDetector(
        onTap: _executeSwing,
        child: Container(
          width: 90 * scale,
          height: 90 * scale,
          decoration: BoxDecoration(
            color: buttonColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
          child: Center(
            child: Text(
              buttonText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22 * scale,
                color: textColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashButton() {
    final scale = _uiScale;
    return Semantics(
      button: true,
      label: 'Dash',
      child: GestureDetector(
        onTap: () {
          flameGame.simulation.dashPlayer();
        },
        child: Container(
          width: 60 * scale,
          height: 60 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFB923C).withValues(alpha: 0.6),
              width: 2.0,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.bolt,
              color: const Color(0xFFFB923C),
              size: 36 * scale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    final scale = _uiScale;
    return GestureDetector(
      onTap: () {
        setState(() {
          final current = simulation.camera.mode.index;
          final next = (current + 1) % CameraMode.values.length;
          simulation.camera.mode = CameraMode.values[next];
        });
      },
      child: Container(
        width: 70 * scale,
        height: 70 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
            width: 2.0,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.videocam,
            color: const Color(0xFFF59E0B),
            size: 36 * scale,
          ),
        ),
      ),
    );
  }

  Widget _buildSpectatorStatsOverlay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: AppTheme.panel(
            accent: AppTheme.danger,
            radius: AppTheme.radiusSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'LIVE  •  SPECTATE',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${simulation.ballSpeed.toStringAsFixed(0)} MPH',
                style: const TextStyle(
                  color: AppTheme.accentLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpectatorBotCard(
              agent: simulation.topBotAgent,
              label: 'TOP BOT',
              color: AppTheme.teamCpu,
              isIncoming: simulation.ball.velocityY < 0,
            ),
            const SizedBox(width: 8),
            SpectatorBotCard(
              agent: simulation.bottomBotAgent,
              label: 'BOTTOM BOT',
              color: AppTheme.teamPlayer,
              isIncoming: simulation.ball.velocityY > 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAltitudeSlider() {
    return RotatedBox(
      quarterTurns: 3, // Vertical slider
      child: Container(
        width: 150,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F24).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
          ),
        ),
        child: Slider(
          min: 0.4,
          max: 2.8,
          activeColor: const Color(0xFFF59E0B),
          inactiveColor: Colors.white12,
          value: simulation.camera.freeRoamZ.clamp(0.4, 2.8),
          onChanged: (val) {
            setState(() {
              simulation.camera.freeRoamZ = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Semantics(
      label: 'Game paused',
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: AngularFrame(
            width: 290,
            cut: 18,
            accent: const Color(0xFFF59E0B),
            fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 28),
                _buildPauseButton(
                  icon: Icons.play_arrow,
                  label: 'RESUME',
                  color: const Color(0xFFF59E0B),
                  textColor: Colors.black,
                  onTap: _togglePause,
                ),
                const SizedBox(height: 12),
                _buildPauseButton(
                  icon: Icons.refresh,
                  label: 'RESTART',
                  color: Colors.transparent,
                  textColor: Colors.white,
                  borderColor: Colors.white54,
                  onTap: () {
                    _showConfirmationDialog(
                      title: 'Restart Match',
                      content: 'Are you sure you want to restart? Your current score will be lost.',
                      onConfirm: () {
                        _startGame();
                        _focusNode.requestFocus();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildPauseButton(
                  icon: Icons.exit_to_app,
                  label: 'QUIT',
                  color: Colors.transparent,
                  textColor: const Color(0xFFE11D48),
                  borderColor: const Color(0xFFE11D48).withValues(alpha: 0.5),
                  onTap: () {
                    _showConfirmationDialog(
                      title: 'Quit Game',
                      content:
                          'Are you sure you want to quit to the main menu?',
                      onConfirm: () {
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: AngularFrame(
            width: 310,
            cut: 16,
            accent: const Color(0xFFF59E0B),
            fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onConfirm();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YES',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchCompleteOverlay() {
    final playerWon = playerScore > botScore;
    return Semantics(
      label: playerWon ? 'You win!' : 'CPU wins',
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: playerWon
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                    : const Color(0xFFE11D48).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: playerWon
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                      : const Color(0xFFE11D48).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerWon ? '🏆 VICTORY' : 'DEFEAT',
                  style: TextStyle(
                    color: playerWon
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE11D48),
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$playerScore - $botScore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () {
                    _startGame();
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'BACK TO MENU',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RefereePopupWidget extends StatefulWidget {
  final String text;
  const RefereePopupWidget({super.key, required this.text});

  @override
  State<RefereePopupWidget> createState() => _RefereePopupWidgetState();
}

class _RefereePopupWidgetState extends State<RefereePopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.text.isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RefereePopupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (widget.text.isNotEmpty) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10),
                ],
              ),
              child: Text(
                widget.text,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
