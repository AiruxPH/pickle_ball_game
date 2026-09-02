import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RallyPhase { botServe, playerServe, playerReturn, botReturn, openRally }

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PickleballGame(),
    ),
  );
}

class PickleballGame extends StatefulWidget {
  const PickleballGame({super.key});

  @override
  State<PickleballGame> createState() => _PickleballGameState();
}

class _PickleballGameState extends State<PickleballGame> {
  final FocusNode _focusNode = FocusNode();

  // Player position on court (-1.0 to 1.0)
  double playerX = 0.0;
  double playerY = 0.75;

  // Bot position
  double botX = 0.0;
  double botY = -0.75;

  // Ball positions (X, Y ground, Z altitude)
  double ballX = 0.0;
  double ballY = 0.0;
  double ballZ = 0.4;

  // Velocities
  double ballSpeedX = 0.01;
  double ballSpeedY = 0.02;
  double ballSpeedZ = 0.02;
  final double gravity = 0.0012;

  // Track who made the last contact
  bool lastHitByPlayer = false;

  // Touch button hold flags
  bool moveLeft = false;
  bool moveRight = false;
  bool moveUp = false;
  bool moveDown = false;
  bool isSwinging = false;

  // Game state
  bool isPlaying = false;
  int playerScore = 0;
  int botScore = 0;
  String feedbackText = "";
  Timer? gameTimer;
  RallyPhase rallyPhase = RallyPhase.botServe;
  bool playerServing = false;
  bool bounceReadyForHit = false;

  void _resetRallyPositions() {
    playerX = 0.0;
    playerY = 0.75;
    botX = 0.0;
    botY = -0.75;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void startGame() {
    setState(() {
      _resetRallyPositions();
      isPlaying = true;
      rallyPhase = playerServing ? RallyPhase.playerServe : RallyPhase.botServe;
      ballX = 0.0;
      ballY = playerServing ? 0.6 : -0.6;
      ballZ = 0.4;
      ballSpeedX = 0.008;
      ballSpeedY = playerServing ? -0.022 : 0.022;
      ballSpeedZ = 0.015;
      lastHitByPlayer = playerServing;
      bounceReadyForHit = false;
      moveLeft = false;
      moveRight = false;
      moveUp = false;
      moveDown = false;
      isSwinging = false;
      feedbackText = "";
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      setState(() {
        // 1. Hardware Keyboard + On-Screen Touch Polling
        const double moveSpeed = 0.025;
        final keyboard = HardwareKeyboard.instance;

        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyA) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) ||
            moveLeft) {
          playerX -= moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyD) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) ||
            moveRight) {
          playerX += moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyW) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowUp) ||
            moveUp) {
          playerY -= moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyS) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowDown) ||
            moveDown) {
          playerY += moveSpeed;
        }

        playerX = playerX.clamp(-0.85, 0.85);
        playerY = playerY.clamp(0.15, 0.9);

        // 2. Ball ground trajectory
        final previousBallY = ballY;
        ballX += ballSpeedX;
        ballY += ballSpeedY;

        // 3. Ball Z-axis (gravity arc)
        ballZ += ballSpeedZ;
        ballSpeedZ -= gravity;

        // Ground bounce & Out-of-bounds check
        if (ballZ <= 0.0) {
          ballZ = 0.0;
          ballSpeedZ = 0.018;

          final ballOnPlayerSide = ballY > 0;
          final validBotServeBounce =
              rallyPhase == RallyPhase.botServe && ballOnPlayerSide;
          final validPlayerServeBounce =
              rallyPhase == RallyPhase.playerServe && !ballOnPlayerSide;
          final validPlayerReturnBounce =
              rallyPhase == RallyPhase.playerReturn && ballOnPlayerSide;
          final validBotReturnBounce =
              rallyPhase == RallyPhase.botReturn && !ballOnPlayerSide;

          if (validBotServeBounce) {
            rallyPhase = RallyPhase.playerReturn;
            bounceReadyForHit = false;
            feedbackText = "RETURN THE SERVE";
          } else if (validPlayerServeBounce) {
            rallyPhase = RallyPhase.botReturn;
            bounceReadyForHit = false;
            feedbackText = "BOT RETURN";
          } else if (validBotReturnBounce) {
            if (bounceReadyForHit) {
              _handleFault(playerAtFault: false, message: "DOUBLE BOUNCE");
              stopGame();
              return;
            }
            bounceReadyForHit = true;
            feedbackText = "BOT RETURN";
          } else if (validPlayerReturnBounce) {
            if (bounceReadyForHit) {
              _handleFault(playerAtFault: true, message: "DOUBLE BOUNCE");
              stopGame();
              return;
            }
            bounceReadyForHit = true;
            feedbackText = "GOOD BOUNCE";
          } else if (rallyPhase == RallyPhase.botServe ||
              rallyPhase == RallyPhase.playerServe ||
              rallyPhase == RallyPhase.playerReturn ||
              rallyPhase == RallyPhase.botReturn) {
            feedbackText = ballOnPlayerSide ? "BOT FAULT" : "YOUR FAULT";
            stopGame();
            return;
          }

          // If the ball hits floor outside sideline or baseline lines
          if (ballX.abs() > 0.82 || ballY.abs() > 0.95) {
            _handleFault(
              playerAtFault: lastHitByPlayer,
              message: "OUT OF BOUNDS",
            );
            stopGame();
            return;
          }
        }

        // A pickleball must clear the net with enough height.
        final crossedNet =
            (previousBallY < 0 && ballY >= 0) ||
            (previousBallY > 0 && ballY <= 0);
        if (crossedNet && ballZ < 0.18) {
          _handleFault(playerAtFault: lastHitByPlayer, message: "NET FAULT");
          stopGame();
          return;
        }

        // 4. Humanized Bot AI
        if (ballSpeedY < 0) {
          double targetX = ballX;
          if ((botX - targetX).abs() > 0.08) {
            if (botX < targetX) {
              botX += 0.009;
            } else {
              botX -= 0.009;
            }
          }
        }
        botX = botX.clamp(-0.85, 0.85);

        // Fixed Bot Strike Zone (requires accurate X, Y, and reasonable height)
        if (ballSpeedY < 0 &&
            rallyPhase == RallyPhase.botReturn &&
            bounceReadyForHit &&
            (ballY - botY).abs() < 0.18 &&
            (ballX - botX).abs() < 0.22 &&
            ballZ < 0.40) {
          lastHitByPlayer = false;
          ballSpeedY = 0.020;
          ballSpeedZ = 0.018;
          ballSpeedX = (ballX - botX) * 0.08;
          bounceReadyForHit = false;
          rallyPhase = RallyPhase.openRally;
        }

        // 5. Backline Pass Check (Safety catch if ball flies off screen)
        if (ballY > 1.15) {
          _handleFault(playerAtFault: lastHitByPlayer, message: "OUT");
          stopGame();
        }
        if (ballY < -1.15) {
          _handleFault(playerAtFault: lastHitByPlayer, message: "OUT");
          stopGame();
        }
      });
    });
  }

  void stopGame() {
    gameTimer?.cancel();
    isPlaying = false;
    moveLeft = false;
    moveRight = false;
    moveUp = false;
    moveDown = false;
  }

  void _handleFault({required bool playerAtFault, required String message}) {
    final servingSideFaulted = playerServing == playerAtFault;
    if (servingSideFaulted) {
      if (playerServing) {
        playerScore++;
      } else {
        botScore++;
      }
      feedbackText = message;
    } else {
      playerServing = !playerServing;
      feedbackText = "SIDE OUT - SERVE CHANGES";
    }
  }

  void executeSwing() {
    final canPlayerHit =
        rallyPhase == RallyPhase.openRally ||
        (rallyPhase == RallyPhase.playerReturn && bounceReadyForHit);
    if (!isPlaying || !canPlayerHit) {
      return;
    }

    setState(() {
      isSwinging = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => isSwinging = false);
    });

    double distToShadow = (ballX - playerX).abs() + (ballY - playerY).abs();

    // Valid hit window
    final ballIsInReach = distToShadow < 0.35 && ballZ > 0.05 && ballZ < 0.6;
    final isKitchenVolley = playerY < 0.2 && ballIsInReach && ballZ > 0.1;
    if (isKitchenVolley) {
      setState(
        () => _handleFault(playerAtFault: true, message: "KITCHEN FAULT"),
      );
      stopGame();
      return;
    }

    if (ballIsInReach) {
      setState(() {
        lastHitByPlayer = true; // Player successfully contacted the ball

        if (ballZ > 0.3) {
          // Smash hit
          ballSpeedY = -0.032;
          ballSpeedZ = 0.01;
          feedbackText = "SMASH!";
        } else {
          // Regular drive
          ballSpeedY = -0.022;
          ballSpeedZ = 0.022;
          feedbackText = "GOOD HIT";
        }
        ballSpeedX = (ballX - playerX) * 0.12;
        if (rallyPhase == RallyPhase.playerReturn) {
          rallyPhase = RallyPhase.botReturn;
        }
      });
    }
  }

  Widget _buildDirectionBtn(IconData icon, void Function(bool) onStateChange) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onStateChange(true),
      onPointerUp: (_) => onStateChange(false),
      onPointerCancel: (_) => onStateChange(false),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white60, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    gameTimer?.cancel();
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
            executeSwing();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.buttons == kSecondaryMouseButton) {
              executeSwing();
            }
          },
          child: Stack(
            children: [
              // Court Surface
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    border: Border.all(color: Colors.white, width: 4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Container(height: 6, color: Colors.white)),
                      Align(
                        alignment: const Alignment(0, -0.3),
                        child: Container(height: 2, color: Colors.white70),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.3),
                        child: Container(height: 2, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              // Bot Character
              Align(
                alignment: Alignment(botX, botY),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_tennis,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Ground Shadow
              Align(
                alignment: Alignment(ballX, ballY),
                child: Container(
                  width: 18 * (1.0 - ballZ * 0.5),
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Ball
              Align(
                alignment: Alignment(ballX, ballY - ballZ),
                child: Container(
                  width: 22 + (ballZ * 10),
                  height: 22 + (ballZ * 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4E157),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Player
              Align(
                alignment: Alignment(playerX, playerY),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: isSwinging ? -15 : 5,
                      child: Transform.rotate(
                        angle: isSwinging ? -0.8 : 0.4,
                        child: Container(
                          width: 14,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSwinging
                                ? Colors.orangeAccent
                                : Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.black87,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Score Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CPU: $botScore",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (feedbackText.isNotEmpty)
                        Text(
                          feedbackText,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      Text(
                        "YOU: $playerScore",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Touch Controls (Mobile)
              if (isPlaying)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        children: [
                          _buildDirectionBtn(
                            Icons.arrow_upward,
                            (val) => moveUp = val,
                          ),
                          Row(
                            children: [
                              _buildDirectionBtn(
                                Icons.arrow_back,
                                (val) => moveLeft = val,
                              ),
                              const SizedBox(width: 48),
                              _buildDirectionBtn(
                                Icons.arrow_forward,
                                (val) => moveRight = val,
                              ),
                            ],
                          ),
                          _buildDirectionBtn(
                            Icons.arrow_downward,
                            (val) => moveDown = val,
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: executeSwing,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 3.5),
                          ),
                          child: const Center(
                            child: Text(
                              "HIT",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.black,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Serve Button Overlay
              if (!isPlaying)
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      startGame();
                      _focusNode.requestFocus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      "TAP TO SERVE",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
