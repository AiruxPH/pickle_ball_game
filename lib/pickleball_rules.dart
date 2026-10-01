class FaultResult {
  const FaultResult({
    required this.playerScore,
    required this.botScore,
    required this.playerServing,
    required this.pointAwarded,
    required this.gameOver,
  });

  final int playerScore;
  final int botScore;
  final bool playerServing;
  final bool pointAwarded;
  final bool gameOver;
}

class PickleballRules {
  static const int winningScore = 11;
  // Official regulation pickleball court proportions (20 ft wide x 44 ft long)
  // Half-court length normalized to 1.0 (22 ft)
  static const double courtLength = 1.0;
  // Half-court width: 10 ft / 22 ft = 0.4545
  static const double courtWidth = 0.4545;
  // Net height: 36 inches / 22 ft = 0.1364 at posts (34 inches / 22 ft = 0.1288 at center)
  static const double netHeight = 0.1364;
  // Non-Volley Zone ("Kitchen"): 7 ft / 22 ft = 0.3182
  static const double kitchenDepth = 0.3182;
  static const double screenCourtScale = 0.9;

  static bool isInsideCourt(double x, double y) {
    return x.abs() <= courtWidth && y.abs() <= courtLength;
  }

  static bool isWinningScore(int playerScore, int botScore) {
    final highestScore = playerScore > botScore ? playerScore : botScore;
    return highestScore >= winningScore && (playerScore - botScore).abs() >= 2;
  }

  static bool isServeInCorrectBox({
    required double x,
    required double y,
    required bool playerServing,
    required bool serveFromLeft,
  }) {
    // Official regulation: Serve must clear the Non-Volley Zone (kitchen line)
    // and land in the diagonal cross-court service box
    // The non-volley-zone line is part of the kitchen, so a serve must
    // land beyond that line. Sidelines, centerline, and baseline remain in.
    final correctYSide = playerServing
        ? (y < -kitchenDepth && y >= -courtLength)
        : (y > kitchenDepth && y <= courtLength);
    final correctXSide = serveFromLeft
        ? (x >= 0 && x <= courtWidth)
        : (x <= 0 && x >= -courtWidth);
    return correctYSide && correctXSide;
  }

  static bool isKitchenVolley({
    required double playerY,
    required bool ballHasBounced,
  }) {
    return playerY < kitchenDepth && !ballHasBounced;
  }

  static FaultResult resolveFault({
    required int playerScore,
    required int botScore,
    required bool playerServing,
    required bool playerAtFault,
  }) {
    if (playerServing == playerAtFault) {
      return FaultResult(
        playerScore: playerScore,
        botScore: botScore,
        playerServing: !playerServing,
        pointAwarded: false,
        gameOver: false,
      );
    }

    final updatedPlayerScore = playerServing ? playerScore + 1 : playerScore;
    final updatedBotScore = playerServing ? botScore : botScore + 1;
    return FaultResult(
      playerScore: updatedPlayerScore,
      botScore: updatedBotScore,
      playerServing: playerServing,
      pointAwarded: true,
      gameOver: isWinningScore(updatedPlayerScore, updatedBotScore),
    );
  }
}
