import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PickleballGame(),
  ));
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
  double playerY = 0.75; // Player stands on bottom half

  // Opponent position
  double botX = 0.0;
  double botY = -0.75;

  // Ball positions (X, Y on ground plane, Z is height)
  double ballX = 0.0;
  double ballY = 0.0;
  double ballZ = 0.4; // Height off ground

  // Velocities
  double ballSpeedX = 0.01;
  double ballSpeedY = 0.02;
  double ballSpeedZ = 0.02;
  final double gravity = 0.0012;

  // Player Movement Flags
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
      ballSpeedY = 0.022; // Serves down toward player
      ballSpeedZ = 0.015;
      feedbackText = "";
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      setState(() {
        // 1. Move Player Character
        const double moveSpeed = 0.03;
        if (moveLeft) playerX -= moveSpeed;
        if (moveRight) playerX += moveSpeed;
        if (moveUp) playerY -= moveSpeed;
        if (moveDown) playerY += moveSpeed;

        // Keep player on their own half (between net and baseline)
        playerX = playerX.clamp(-0.85, 0.85);
        playerY = playerY.clamp(0.15, 0.9);

        // 2. Ball Ground Movement
        ballX += ballSpeedX;
        ballY += ballSpeedY;

        // 3. Ball Z-axis (Gravity Arc)
        ballZ += ballSpeedZ;
        ballSpeedZ -= gravity;

        // Ball bounce on the floor
        if (ballZ <= 0.0) {
          ballZ = 0.0;
          ballSpeedZ = 0.018; // Bounce upward
        }

        // Side boundary wall bounce
        if (ballX <= -0.9 || ballX >= 0.9) {
          ballSpeedX = -ballSpeedX;
        }

        // 4. Opponent AI: Glide toward ball shadow
        if (botX < ballX) botX += 0.014;
        if (botX > ballX) botX -= 0.014;
        botX = botX.clamp(-0.85, 0.85);

        // Opponent auto-swings when ball enters their zone
        if (ballY <= -0.65 && (ballX - botX).abs() < 0.25 && ballZ < 0.5) {
          ballSpeedY = 0.022; // Hit back toward player
          ballSpeedZ = 0.02; // Lob it upward
          ballSpeedX = (ballX - botX) * 0.1; // Add direction angle
        }

        // 5. Out of bounds / Miss check
        if (ballY > 1.1) {
          botScore++;
          feedbackText = "OUT! BOT POINT";
          stopGame();
        }
        if (ballY < -1.1) {
          playerScore++;
          feedbackText = "POINT FOR YOU!";
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

  // Player Swing Logic
  void executeSwing() {
    if (!isPlaying) return;

    setState(() {
      isSwinging = true;
    });

    // Reset swing visual after 150ms
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => isSwinging = false);
    });

    // Proximity check on the floor plane
    double distToShadow = (ballX - playerX).abs() + (ballY - playerY).abs();

    // Valid hit window: character is near shadow and ball is at hittable height
    if (distToShadow < 0.35 && ballZ > 0.05 && ballZ < 0.6) {
      setState(() {
        if (ballZ > 0.3) {
          // Smash hit: fast and sharp
          ballSpeedY = -0.032;
          ballSpeedZ = 0.01;
          feedbackText = "SMASH!";
        } else {
          // Regular drive
          ballSpeedY = -0.022;
          ballSpeedZ = 0.022;
          feedbackText = "GOOD HIT";
        }
        // Slice angle based on player offset
        ballSpeedX = (ballX - playerX) * 0.12;
      });
    }
  }

  void handleKeyEvent(KeyEvent event) {
    bool isDown = event is KeyDownEvent;

    if (event.logicalKey == LogicalKeyboardKey.keyA ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      moveLeft = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.keyD ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      moveRight = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.keyW ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      moveUp = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.keyS ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      moveDown = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.space && isDown) {
      executeSwing();
    }
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
      backgroundColor: const Color(0xFF1E3A8A), // Deep stadium blue
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: handleKeyEvent,
        child: Stack(
          children: [
            // Pickleball Court Surface
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32), // Green court
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    // Center Net
                    Center(
                      child: Container(
                        height: 6,
                        color: Colors.white,
                      ),
                    ),

                    // Non-Volley Kitchen Lines (Wii style court zones)
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

            // Opponent Character (Top)
            Align(
              alignment: Alignment(botX, botY),
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

            // Ball Floor Shadow (Gives 3D depth)
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

            // The Ball (Drawn directly above its shadow based on ballZ)
            Align(
              alignment: Alignment(ballX, ballY - ballZ),
              child: Container(
                width: 22 + (ballZ * 10),
                height: 22 + (ballZ * 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4E157), // Neon Pickleball
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
              ),
            ),

            // Player Character + Paddle (Bottom)
            Align(
              alignment: Alignment(playerX, playerY),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Body
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

                  // Paddle / Swing Arc Indicator
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

            // Scoreboard & Hit Feedback
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

            // Mobile On-Screen Controls (Visible on mobile/tablets)
            if (isPlaying)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // D-Pad for Touch Movement
                    Column(
                      children: [
                        IconButton.filled(
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: () => setState(() => playerY = (playerY - 0.08).clamp(0.15, 0.9)),
                        ),
                        Row(
                          children: [
                            IconButton.filled(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => setState(() => playerX = (playerX - 0.08).clamp(-0.85, 0.85)),
                            ),
                            const SizedBox(width: 40),
                            IconButton.filled(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () => setState(() => playerX = (playerX + 0.08).clamp(-0.85, 0.85)),
                            ),
                          ],
                        ),
                        IconButton.filled(
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: () => setState(() => playerY = (playerY + 0.08).clamp(0.15, 0.9)),
                        ),
                      ],
                    ),

                    // Big Swing Button
                    GestureDetector(
                      onTap: executeSwing,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: Text(
                            "HIT",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Serve / Start Overlay
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
    );
  }
}