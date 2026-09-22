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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SettingsManager().init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoadingScreen(),
    ),
  );
}

class PickleballGame extends StatefulWidget {
  final int gameMode; // 0 = PlayerVsBot, 1 = BotVsBot
  const PickleballGame({super.key, this.gameMode = 0});

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

  @override
  void initState() {
    super.initState();
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
      ),
    );
    flameGame.onRallyEnd = _handleRallyEnd;
    flameGame.simulation.onPlayerDash = (x, y) {
      flameGame.spawnDashEffect(x: x, y: y, isPlayer: true);
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
        serverScore: match.servingSide == MatchSide.player ? match.playerScore : match.botScore,
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
    setState(() {
      final previousPlayerScore = playerScore;
      final previousBotScore = botScore;
      final pointWinner =
          rallyEnd == RallyEnd.playerFault ? MatchSide.bot : MatchSide.player;
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
            if (feedbackText == 'POINT FOR YOU!' || feedbackText == 'POINT FOR CPU!' || feedbackText == 'SIDE OUT!') {
              setState(() => feedbackText = '');
            }
            setState(() {
              simulation.resetRally(
                servingSide: match.servingSide,
                serverScore: match.servingSide == MatchSide.player ? match.playerScore : match.botScore,
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
        flameGame.spawnHitEffect(isSmash: wasHighBall);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && (feedbackText == 'SMASH!' || feedbackText == 'GOOD HIT')) {
            setState(() => feedbackText = '');
          }
        });
      } else if (swingResult == SwingResult.twoBounceFault) {
        feedbackText = 'TWO-BOUNCE FAULT!';
        _handleRallyEnd(RallyEnd.playerFault);
      } else if (swingResult == SwingResult.kitchenFault) {
        feedbackText = 'KITCHEN FAULT!';
        _handleRallyEnd(RallyEnd.playerFault);
      } else {
        feedbackText = 'MISSED!';
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && feedbackText == 'MISSED!') {
            setState(() => feedbackText = '');
          }
        });
      }
    });
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Hitboxes', style: TextStyle(color: Colors.white)),
              value: GameDebugConfig.showHitboxes,
              onChanged: (val) => setState(() => GameDebugConfig.showHitboxes = val),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Freeze AI', style: TextStyle(color: Colors.white)),
              value: GameDebugConfig.freezeAI,
              onChanged: (val) => setState(() => GameDebugConfig.freezeAI = val),
            ),
            Text('Speed: ${GameDebugConfig.gameSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70)),
            Slider(
              min: 0.0,
              max: 2.0,
              divisions: 20,
              value: GameDebugConfig.gameSpeed,
              onChanged: (val) => setState(() => GameDebugConfig.gameSpeed = val),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Bypass Kitchen Rules', style: TextStyle(color: Colors.white, fontSize: 12)),
              value: GameDebugConfig.bypassKitchenRules,
              onChanged: (val) => setState(() => GameDebugConfig.bypassKitchenRules = val),
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
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            _executeSwing();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (isPlaying) _togglePause();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight)) {
            flameGame.simulation.dashPlayer();
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
                      if (widget.gameMode == 1 && simulation.camera.mode == CameraMode.freeRoam) {
                        setState(() {
                          if (details.scale != 1.0) {
                             simulation.camera.freeRoamZ = (_initialZoomZ / details.scale).clamp(1.0, 10.0);
                          }
                          // Handle panning
                          simulation.camera.freeRoamYaw -= details.focalPointDelta.dx * 0.01;
                          simulation.camera.freeRoamPitch -= details.focalPointDelta.dy * 0.01;
                          simulation.camera.freeRoamPitch = simulation.camera.freeRoamPitch.clamp(-math.pi / 2.1, math.pi / 2.1);
                        });
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isPlaying)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 22),
                                  tooltip: _isPaused ? 'Resume game' : 'Pause game',
                                  onPressed: _togglePause,
                                )
                              else
                                const SizedBox(width: 36),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: const Icon(Icons.bug_report, color: Colors.white70, size: 22),
                                tooltip: 'Debug menu',
                                onPressed: () => setState(() => _showDebugMenu = !_showDebugMenu),
                              ),
                              if (widget.gameMode != 2) Expanded(
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1F24).withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Semantics(
                                            liveRegion: true,
                                            label: 'CPU score $botScore',
                                            child: Text('CPU: $botScore',
                                                style: const TextStyle(color: const Color(0xFFE11D48), fontSize: 14, fontWeight: FontWeight.bold)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 14)),
                                          ),
                                          Semantics(
                                            liveRegion: true,
                                            label: 'Your score $playerScore',
                                            child: Text('YOU: $playerScore',
                                                style: const TextStyle(color: const Color(0xFFF59E0B), fontSize: 14, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ) else const Spacer(),
                              const SizedBox(width: 36),
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
                      bottom: 120, // above the joystick and hit button
                      left: 16,
                      child: IgnorePointer(
                        child: RefereePopupWidget(text: feedbackText),
                      ),
                    ),
                  if (isPlaying && !_isPaused && (widget.gameMode == 0 || widget.gameMode == 2))
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: ListenableBuilder(
                        listenable: SettingsManager(),
                        builder: (context, child) {
                          final settings = SettingsManager();
                          final joystick = _buildJoystick();
                          final actionButtons = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDashButton(),
                              const SizedBox(width: 16),
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
                      top: 16,
                      right: 16,
                      child: _buildSpectatorStatsOverlay(),
                    ),
                  if (isPlaying && !_isPaused && widget.gameMode == 1)
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (simulation.camera.mode == CameraMode.freeRoam) _buildJoystick() else const SizedBox(width: 80, height: 80),
                          Row(
                            children: [
                              if (simulation.camera.mode == CameraMode.freeRoam) _buildAltitudeSlider(),
                              const SizedBox(width: 16),
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
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 2),
          ),
          child: Center(
            child: Transform.translate(
              offset: _input.knobOffset,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2),
                    const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
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
    final isPlayerServing = simulation.playPhase == MatchPlayPhase.waitingForServe && simulation.servingSide == MatchSide.player;
    final buttonText = isPlayerServing ? 'SERVE' : 'HIT';
    final buttonColor = isPlayerServing ? const Color(0xFFFF6D00) : const Color(0xFFF59E0B);
    final textColor = isPlayerServing ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      label: isPlayerServing ? 'Serve the ball' : 'Hit the ball',
      child: GestureDetector(
        onTap: _executeSwing,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: buttonColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: buttonColor.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 3),
              const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
          ),
          child: Center(
            child: Text(buttonText,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor, letterSpacing: 1.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildDashButton() {
    return Semantics(
      button: true,
      label: 'Dash',
      child: GestureDetector(
        onTap: () {
          flameGame.simulation.dashPlayer();
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFFFB923C).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
              const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0xFFFB923C).withValues(alpha: 0.6), width: 2.0),
          ),
          child: const Center(
            child: Icon(Icons.bolt, color: const Color(0xFFFB923C), size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          final current = simulation.camera.mode.index;
          final next = (current + 1) % CameraMode.values.length;
          simulation.camera.mode = CameraMode.values[next];
        });
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
            const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          ],
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 2.0),
        ),
        child: const Center(
          child: Icon(Icons.videocam, color: const Color(0xFFF59E0B), size: 36),
        ),
      ),
    );
  }

  Widget _buildSpectatorStatsOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LIVE BROADCAST', style: TextStyle(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text('RALLY: ${simulation.rallyLength}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          Text('BALL SPEED: ${simulation.ballSpeed.toStringAsFixed(0)} MPH', style: const TextStyle(color: const Color(0xFFF59E0B), fontSize: 14)),
        ],
      ),
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
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        ),
        child: Slider(
          min: 1.0,
          max: 10.0,
          activeColor: const Color(0xFFF59E0B),
          inactiveColor: Colors.white12,
          value: simulation.camera.freeRoamZ,
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
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5),
                BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('PAUSED',
                    style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 32),
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
                      content: 'Are you sure you want to quit to the main menu?',
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
          border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog({required String title, required String content, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title.toUpperCase(), style: const TextStyle(color: const Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 16),
                Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onConfirm();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('YES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
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
                color: playerWon ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFE11D48).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: playerWon ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFFE11D48).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerWon ? '🏆 VICTORY' : 'DEFEAT',
                  style: TextStyle(
                      color: playerWon ? const Color(0xFFF59E0B) : const Color(0xFFE11D48),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3),
                ),
                const SizedBox(height: 16),
                Text('$playerScore - $botScore',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                      child: Text('PLAY AGAIN',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
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
                      child: Text('BACK TO MENU',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 16)),
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
  const RefereePopupWidget({Key? key, required this.text}) : super(key: key);

  @override
  State<RefereePopupWidget> createState() => _RefereePopupWidgetState();
}

class _RefereePopupWidgetState extends State<RefereePopupWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
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
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
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
