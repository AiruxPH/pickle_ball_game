import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PickleballCourt(),
  ));
}

class PickleballCourt extends StatefulWidget {
  const PickleballCourt({super.key});

  @override
  State<PickleballCourt> createState() => _PickleballCourtState();
}

class _PickleballCourtState extends State<PickleballCourt> {
  final FocusNode _focusNode = FocusNode();

  // Positions (-1.0 to 1.0)
  double playerPaddleX = 0.0;
  double botPaddleX = 0.0;

  // Ball
  double ballX = 0.0;
  double ballY = 0.0;
  double speedX = 0.015;
  double speedY = 0.02;

  // Smooth keyboard flags
  bool movingLeft = false;
  bool movingRight = false;
  final double paddleSpeed = 0.025;

  // Scores
  int playerScore = 0;
  int botScore = 0;

  Timer? gameTimer;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();

    // Disable browser right-click menu
    BrowserContextMenu.disableContextMenu();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void startGame() {
    setState(() {
      isPlaying = true;
      ballX = 0.0;
      ballY = 0.0;
      speedY = 0.02;
      speedX = 0.015;
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      setState(() {
        // Smooth keyboard motion
        if (movingLeft) {
          playerPaddleX -= paddleSpeed;
        }
        if (movingRight) {
          playerPaddleX += paddleSpeed;
        }
        playerPaddleX = playerPaddleX.clamp(-0.8, 0.8);

        // Ball movement
        ballX += speedX;
        ballY += speedY;

        // Bot AI
        if (botPaddleX < ballX) {
          botPaddleX += 0.012;
        } else if (botPaddleX > ballX) {
          botPaddleX -= 0.012;
        }
        botPaddleX = botPaddleX.clamp(-0.8, 0.8);

        // Wall bounce
        if (ballX <= -0.95 || ballX >= 0.95) {
          speedX = -speedX;
        }

        // Paddle collisions
        if (ballY >= 0.82 && ballY <= 0.88 && (ballX - playerPaddleX).abs() < 0.25) {
          speedY = -speedY.abs();
        }
        if (ballY <= -0.82 && ballY >= -0.88 && (ballX - botPaddleX).abs() < 0.25) {
          speedY = speedY.abs();
        }

        // Scores
        if (ballY > 1.1) {
          botScore++;
          stopGame();
        }
        if (ballY < -1.1) {
          playerScore++;
          stopGame();
        }
      });
    });
  }

  void stopGame() {
    gameTimer?.cancel();
    isPlaying = false;
    movingLeft = false;
    movingRight = false;
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        movingLeft = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        movingRight = true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        movingLeft = false;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        movingRight = false;
      }
    }
  }

  void movePaddle(double deltaX) {
    setState(() {
      playerPaddleX += deltaX / (MediaQuery.of(context).size.width / 2);
      playerPaddleX = playerPaddleX.clamp(-0.8, 0.8);
    });
  }

  @override
  void dispose() {
    BrowserContextMenu.enableContextMenu();
    gameTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // <--- The build method starts right here --->
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1B4332),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: handleKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerMove: (event) {
            // Checks if right-click is held AND cursor is on bottom half of the court
            if (event.buttons == kSecondaryMouseButton &&
                event.position.dy > screenHeight / 2) {
              movePaddle(event.delta.dx);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              // Allows drag anywhere on bottom half
              if (details.localPosition.dy > screenHeight / 2) {
                movePaddle(details.delta.dx);
              }
            },
            child: Stack(
              children: [
                // Net
                Center(
                  child: Container(
                    height: 3,
                    color: Colors.white60,
                  ),
                ),

                // Bot Paddle (Top)
                Align(
                  alignment: Alignment(botPaddleX, -0.85),
                  child: Container(
                    width: 100,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Player Paddle (Bottom)
                Align(
                  alignment: Alignment(playerPaddleX, 0.85),
                  child: Container(
                    width: 100,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Ball
                Align(
                  alignment: Alignment(ballX, ballY),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9D700),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Scoreboard
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Bot: $botScore",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "You: $playerScore",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Serve Button
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
                            horizontal: 32, vertical: 14),
                      ),
                      child: const Text(
                        "TAP TO SERVE",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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