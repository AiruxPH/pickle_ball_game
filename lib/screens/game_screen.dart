import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_debug_config.dart';
import '../game_input_adapter.dart';
import '../game_simulation.dart';
import '../match_state.dart';
import '../pickleball_flame_game.dart';
import '../settings_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/game_controls_overlay.dart';
import '../widgets/game_debug_panel.dart';
import '../widgets/game_pause_overlay.dart';
import '../widgets/match_complete_overlay.dart';
import '../widgets/match_hud.dart';
import '../widgets/practice_hud.dart';
import '../widgets/referee_popup_widget.dart';
import '../widgets/spectator_stats_overlay.dart';

/// Primary gameplay screen hosting the 3D Flame simulation canvas and all HUD overlays.
class PickleballGame extends StatefulWidget {
  final int gameMode; // 0 = PlayerVsBot, 1 = BotVsBot, 2 = Practice
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
      (MediaQuery.sizeOf(context).height / 600).clamp(0.55, 1.0);

  @override
  void initState() {
    super.initState();
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
      flameGame.randomizeBotPaddles();
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

              // Player touch controls
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
                      final isServing =
                          simulation.playPhase ==
                              MatchPlayPhase.waitingForServe &&
                          simulation.servingSide == MatchSide.player;

                      final joystick = VirtualJoystickWidget(
                        input: _input,
                        scale: _uiScale,
                        onInputUpdate: () => setState(() {}),
                      );

                      final actionButtons = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DashButtonWidget(
                            scale: _uiScale,
                            onTap: () => flameGame.simulation.dashPlayer(),
                          ),
                          SizedBox(width: 16 * _uiScale),
                          HitButtonWidget(
                            isServing: isServing,
                            scale: _uiScale,
                            onTap: _executeSwing,
                          ),
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

              // Spectator stats
              if (isPlaying && !_isPaused && widget.gameMode == 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Transform.scale(
                    scale: _uiScale,
                    alignment: Alignment.topRight,
                    child: SpectatorStatsOverlay(simulation: simulation),
                  ),
                ),

              // Spectator camera & free-roam controls
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
                        VirtualJoystickWidget(
                          input: _input,
                          scale: _uiScale,
                          onInputUpdate: () => setState(() {}),
                        )
                      else
                        SizedBox(width: 80 * _uiScale, height: 80 * _uiScale),
                      Row(
                        children: [
                          if (simulation.camera.mode == CameraMode.freeRoam)
                            AltitudeSliderWidget(
                              value: simulation.camera.freeRoamZ,
                              onChanged: (val) {
                                setState(() {
                                  simulation.camera.freeRoamZ = val;
                                });
                              },
                            ),
                          SizedBox(width: 16 * _uiScale),
                          CameraButtonWidget(
                            scale: _uiScale,
                            onTap: () {
                              setState(() {
                                final current = simulation.camera.mode.index;
                                final next =
                                    (current + 1) % CameraMode.values.length;
                                simulation.camera.mode =
                                    CameraMode.values[next];
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_isPaused)
                GamePauseOverlay(
                  onResume: _togglePause,
                  onRestart: () {
                    _startGame();
                    _focusNode.requestFocus();
                  },
                  onQuit: () => Navigator.of(context).pop(),
                ),

              if (match.isComplete)
                MatchCompleteOverlay(
                  playerScore: playerScore,
                  botScore: botScore,
                  onPlayAgain: () {
                    _startGame();
                    _focusNode.requestFocus();
                  },
                  onBackToMenu: () => Navigator.of(context).pop(),
                ),

              if (_showDebugMenu)
                GameDebugPanel(
                  onFastForwardScore: () {
                    setState(() {
                      match.playerScore = 10;
                      match.botScore = 10;
                      simulation.currentServerScore = 10;
                    });
                  },
                  onConfigChanged: () => setState(() {}),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
