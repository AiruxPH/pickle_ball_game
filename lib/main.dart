import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(0, 0, size.width, size.height);
    final grassPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(court, grassPaint);

    final stripePaint = Paint()
      ..color = const Color(0xFF388E3C).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    for (var index = 0; index < 10; index++) {
      final stripe = Rect.fromLTWH(
        size.width * index / 10,
        0,
        size.width / 20,
        size.height,
      );
      canvas.drawRect(stripe, stripePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const courtInset = 2.0;
    final left = courtInset;
    final right = size.width - courtInset;
    final top = courtInset;
    final bottom = size.height - courtInset;
    final centerX = size.width / 2;
    final kitchenTop = size.height * 0.35;
    final kitchenBottom = size.height * 0.65;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), linePaint);
    canvas.drawLine(Offset(left, kitchenTop), Offset(right, kitchenTop), linePaint);
    canvas.drawLine(Offset(left, kitchenBottom), Offset(right, kitchenBottom), linePaint);
    canvas.drawLine(Offset(centerX, top), Offset(centerX, kitchenTop), linePaint);
    canvas.drawLine(Offset(centerX, kitchenBottom), Offset(centerX, bottom), linePaint);

    final kitchenPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(left, kitchenTop, right, kitchenBottom),
      kitchenPaint,
    );

    final netPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(left, size.height / 2), Offset(right, size.height / 2), netPaint);
    canvas.drawCircle(Offset(left, size.height / 2), 6, netPaint);
    canvas.drawCircle(Offset(right, size.height / 2), 6, netPaint);

    final netShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..strokeWidth = 10;
    canvas.drawLine(Offset(left, size.height / 2 + 7), Offset(right, size.height / 2 + 7), netShadowPaint);
  }

  @override
  bool shouldRepaint(covariant CourtPainter oldDelegate) => false;
}

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

  // Positions
  double playerX = 0.0;
  double playerY = 0.75;
  double botX = 0.0;
  double botY = -0.75;
  double ballX = 0.0;
  double ballY = 0.0;
  double ballZ = 0.4;

  // Velocities
  double ballSpeedX = 0.01;
  double ballSpeedY = 0.02;
  double ballSpeedZ = 0.02;
  final double gravity = 0.0012;

  // Joystick state
  double joystickX = 0.0;
  double joystickY = 0.0;

  bool lastHitByPlayer = false;
  bool isSwinging = false;
  bool isPlaying = false;
  
  int playerScore = 0;
  int botScore = 0;
  String feedbackText = "";
  Timer? gameTimer;

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
      isPlaying = true;
      ballX = 0.0;
      ballY = -0.6;
      ballZ = 0.4;
      ballSpeedX = 0.008;
      ballSpeedY = 0.022;
      ballSpeedZ = 0.015;
      lastHitByPlayer = false;
      feedbackText = "";
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      setState(() {
        // 1. Smooth Hardware Polling & Mobile Joystick
        const double moveSpeed = 0.025;
        final keyboard = HardwareKeyboard.instance;

        playerX += joystickX * moveSpeed;
        playerY += joystickY * moveSpeed;

        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyA) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          playerX -= moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyD) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight)) {
          playerX += moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyW) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowUp)) {
          playerY -= moveSpeed;
        }
        if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyS) ||
            keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowDown)) {
          playerY += moveSpeed;
        }

        // EXPANDED BOUNDARIES: Let the player run wide into the blue void to catch stray balls
        playerX = playerX.clamp(-1.4, 1.4);
        playerY = playerY.clamp(0.05, 1.3);

        // 2. Ball trajectory
        ballX += ballSpeedX;
        ballY += ballSpeedY;
        ballZ += ballSpeedZ;
        ballSpeedZ -= gravity;

        // Ground bounce & Out-of-bounds check
        if (ballZ <= 0.0) {
          ballZ = 0.0;
          ballSpeedZ = 0.018;

          if (ballX.abs() > 0.85 || ballY.abs() > 0.95) {
            if (lastHitByPlayer) {
              botScore++;
              feedbackText = "OUT! YOUR FAULT";
            } else {
              playerScore++;
              feedbackText = "OUT! BOT FAULT";
            }
            stopGame();
            return;
          }
        }

        // 3. Humanized Bot AI
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
        
        // Let the bot stretch out wide too
        botX = botX.clamp(-1.4, 1.4);

        if (ballSpeedY < 0 && (ballY - botY).abs() < 0.18 && (ballX - botX).abs() < 0.22 && ballZ < 0.40) {
          lastHitByPlayer = false;
          ballSpeedY = 0.020;
          ballSpeedZ = 0.018;
          ballSpeedX = (ballX - botX) * 0.08;
        }

        // 4. Backline Pass Check
        if (ballY > 1.15) {
          if (lastHitByPlayer) {
            botScore++;
            feedbackText = "OUT! YOUR FAULT";
          } else {
            playerScore++;
            feedbackText = "POINT FOR YOU!";
          }
          stopGame();
        }
        if (ballY < -1.15) {
          if (lastHitByPlayer) {
            playerScore++;
            feedbackText = "POINT FOR YOU!";
          } else {
            botScore++;
            feedbackText = "OUT! BOT FAULT";
          }
          stopGame();
        }
      });
    });
  }

  void stopGame() {
    gameTimer?.cancel();
    isPlaying = false;
    joystickX = 0.0;
    joystickY = 0.0;
  }

  void executeSwing() {
    if (!isPlaying) return;

    setState(() {
      isSwinging = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => isSwinging = false);
    });

    double distToShadow = (ballX - playerX).abs() + (ballY - playerY).abs();

    if (distToShadow < 0.35 && ballZ > 0.05 && ballZ < 0.6) {
      setState(() {
        lastHitByPlayer = true;

        if (ballZ > 0.3) {
          ballSpeedY = -0.032;
          ballSpeedZ = 0.01;
          feedbackText = "SMASH!";
        } else {
          ballSpeedY = -0.022;
          ballSpeedZ = 0.022;
          feedbackText = "GOOD HIT";
        }
        ballSpeedX = (ballX - playerX) * 0.12;
      });
    }
  }

  Widget _buildJoystick() {
    return GestureDetector(
      onPanStart: (details) => _updateJoystick(details.localPosition),
      onPanUpdate: (details) => _updateJoystick(details.localPosition),
      onPanEnd: (details) {
        setState(() {
          joystickX = 0.0;
          joystickY = 0.0;
        });
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(joystickX * 45, joystickY * 45),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateJoystick(Offset localPosition) {
    double dx = localPosition.dx - 70;
    double dy = localPosition.dy - 70;
    
    double distance = math.sqrt(dx * dx + dy * dy);
    
    if (distance > 45) {
      dx = (dx / distance) * 45;
      dy = (dy / distance) * 45;
    }
    
    setState(() {
      joystickX = dx / 45;
      joystickY = dy / 45;
    });
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
    final screenHeight = MediaQuery.of(context).size.height;
    final courtScale = (screenHeight / 850).clamp(0.4, 1.2);

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
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
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    child: Stack(
                      // ADDED: This ensures the player isn't visually cut off when running outside the green court
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: CourtPainter()),
                        ),
                        Align(
                          alignment: Alignment(botX, botY),
                          child: Transform.scale(
                            scale: courtScale,
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
                              ),
                              child: const Icon(Icons.sports_tennis, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(ballX, ballY),
                          child: Transform.scale(
                            scale: courtScale,
                            child: Container(
                              width: 18 * (1.0 - ballZ * 0.5),
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(ballX, ballY - ballZ),
                          child: Transform.scale(
                            scale: courtScale,
                            child: Container(
                              width: 22 + (ballZ * 10),
                              height: 22 + (ballZ * 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4E157),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                ],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(playerX, playerY),
                          child: Transform.scale(
                            scale: courtScale,
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
                                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 32),
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
                                        color: isSwinging ? Colors.orangeAccent : Colors.amber,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.black87, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("CPU: $botScore", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (feedbackText.isNotEmpty)
                        Text(feedbackText, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text("YOU: $playerScore", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (isPlaying)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildJoystick(),
                      GestureDetector(
                        onTap: executeSwing,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
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
              if (!isPlaying)
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      startGame();
                      _focusNode.requestFocus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    ),
                    child: const Text(
                      "TAP TO SERVE",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
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