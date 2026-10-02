import 'package:flutter/material.dart';

/// Full-screen victory / defeat overlay shown when a match concludes.
class MatchCompleteOverlay extends StatelessWidget {
  final int playerScore;
  final int botScore;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToMenu;

  const MatchCompleteOverlay({
    super.key,
    required this.playerScore,
    required this.botScore,
    required this.onPlayAgain,
    required this.onBackToMenu,
  });

  @override
  Widget build(BuildContext context) {
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
                  onTap: onPlayAgain,
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
                  onTap: onBackToMenu,
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
