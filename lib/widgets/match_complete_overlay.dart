import 'package:flutter/material.dart';

/// Full-screen victory / defeat overlay shown when a match concludes.
/// Adapts responsively across resolutions and prevents vertical overflows.
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 420;
    final superCompact = size.height < 320;
    final playerWon = playerScore > botScore;

    return Semantics(
      label: playerWon ? 'You win!' : 'CPU wins',
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: superCompact ? 280 : 320,
              padding: EdgeInsets.symmetric(
                vertical: superCompact ? 16 : (compact ? 22 : 36),
                horizontal: compact ? 20 : 28,
              ),
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
                      fontSize: superCompact ? 24 : (compact ? 28 : 36),
                      fontWeight: FontWeight.w900,
                      letterSpacing: compact ? 2 : 3,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  Text(
                    '$playerScore - $botScore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: superCompact ? 20 : (compact ? 24 : 28),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: superCompact ? 14 : (compact ? 20 : 36)),
                  GestureDetector(
                    onTap: onPlayAgain,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'PLAY AGAIN',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 18,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  GestureDetector(
                    onTap: onBackToMenu,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          'BACK TO MENU',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 13 : 16,
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
      ),
    );
  }
}
