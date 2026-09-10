import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_simulation.dart';
import 'match_state.dart';
import 'pickleball_flame_game.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainMenu(), // The app now boots into the menu
    ),
  );
}

// The New Title Screen
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Check if the screen is wider than it is tall
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // 2. We separate the Logo into its own variable to keep the code clean
    final logoWidget = Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFFD4E157),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))
        ],
      ),
      child: const Icon(Icons.sports_tennis, size: 80, color: Color(0xFF1E3A8A)),
    );

    // 3. We separate the Text and Button into another variable
    final textAndButtonWidget = Column(
      mainAxisSize: MainAxisSize.min, // Prevents it from taking up infinite vertical space
      children: [
        const Text(
          "PRO PICKLEBALL",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Wii-Style Mechanics",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PickleballGame()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 8,
          ),
          child: const Text(
            "PLAY NOW",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        // The scroll view saves us from overflow crashes on tiny screens
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // 4. The Magic Layout Swap
            child: isLandscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      logoWidget,
                      const SizedBox(width: 60),
                      textAndButtonWidget,
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      logoWidget,
                      const SizedBox(height: 40),
                      textAndButtonWidget,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class PickleballGame extends StatefulWidget {
  const PickleballGame({super.key});

  @override
  State<PickleballGame> createState() => _PickleballGameState();
}

class _PickleballGameState extends State<PickleballGame> {
  final FocusNode _focusNode = FocusNode();
  final MatchState match = MatchState();
  final PickleballFlameGame flameGame;

  _PickleballGameState() : flameGame = PickleballFlameGame();

  GameSimulation get simulation => flameGame.simulation;

  double get playerX => simulation.playerX;
  double get playerY => simulation.playerY;
  double get botX => simulation.botX;
  double get botY => simulation.botY;
  double get ballZ => simulation.ball.z;

  // Joystick state
  double joystickX = 0.0;
  double joystickY = 0.0;

  bool lastHitByPlayer = false;
  bool isSwinging = false;
  bool isPlaying = false;
  
  int get playerScore => match.playerScore;
  int get botScore => match.botScore;
  String feedbackText = "";

  @override
  void initState() {
    super.initState();
    flameGame.onRallyEnd = _handleRallyEnd;
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void startGame() {
    setState(() {
      if (match.isComplete) {
        match.reset();
      }
      match.start();
      isPlaying = true;
      simulation.resetRally();
      lastHitByPlayer = simulation.lastHitByPlayer;
      feedbackText = "";
    });
    flameGame.start();
  }

  void _handleRallyEnd(RallyEnd rallyEnd) {
    if (!mounted) return;

    setState(() {
      lastHitByPlayer = simulation.lastHitByPlayer;
      final previousPlayerScore = playerScore;
      final previousBotScore = botScore;
      final faultSide = rallyEnd == RallyEnd.playerFault
          ? MatchSide.player
          : MatchSide.bot;
      final pointWinner = faultSide == MatchSide.player
          ? MatchSide.bot
          : MatchSide.player;
      match.awardPointTo(pointWinner);

      if (match.isComplete) {
        feedbackText = playerScore > botScore ? "YOU WIN!" : "CPU WINS";
      } else if (playerScore > previousPlayerScore) {
        feedbackText = "POINT FOR YOU!";
      } else if (botScore > previousBotScore) {
        feedbackText = "POINT FOR CPU!";
      }
      isPlaying = false;
      joystickX = 0;
      joystickY = 0;
    });
  }

  void stopGame() {
    flameGame.stop();
    isPlaying = false;
    joystickX = 0.0;
    joystickY = 0.0;
  }

  void executeSwing() {
    if (!isPlaying) return;

    setState(() {
      isSwinging = true;
      flameGame.isSwinging = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          isSwinging = false;
          flameGame.isSwinging = false;
        });
      }
    });

    final wasHighBall = ballZ > 0.3;
    final swingResult = simulation.swing();
    if (swingResult == SwingResult.hit) {
      setState(() {
        lastHitByPlayer = simulation.lastHitByPlayer;
        if (wasHighBall) {
          feedbackText = "SMASH!";
        } else {
          feedbackText = "GOOD HIT";
        }
      });
    } else {
      setState(() {
        feedbackText = swingResult == SwingResult.kitchenFault
            ? "KITCHEN FAULT"
            : "MISS";
      });
    }
  }

  Widget _buildJoystick() {
    return Semantics(
      label: 'Move player',
      child: GestureDetector(
        onPanStart: (details) => _updateJoystick(details.localPosition),
        onPanUpdate: (details) => _updateJoystick(details.localPosition),
        onPanEnd: (details) {
          setState(() {
            joystickX = 0.0;
            joystickY = 0.0;
            flameGame.inputX = 0.0;
            flameGame.inputY = 0.0;
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
      flameGame.inputX = joystickX;
      flameGame.inputY = joystickY;
    });
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
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
              Positioned.fill(
                child: IgnorePointer(
                  child: GameWidget(game: flameGame),
                ),
              ),
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Added a back button to quit the current game
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text("CPU: $botScore", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (feedbackText.isNotEmpty)
                        Text(feedbackText, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text("YOU: $playerScore", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 48), // Balances the layout opposite the back button
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
                      Semantics(
                        button: true,
                        label: 'Hit the ball',
                        child: GestureDetector(
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