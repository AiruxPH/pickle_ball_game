enum RallyPhase { botServe, playerServe, playerReturn, botReturn, openRally }

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
  static const double courtWidth = 0.82;
  static const double courtLength = 0.95;
  static const double netHeight = 0.18;
  static const double screenCourtScale = 0.9;
  static const double kitchenDepth = 0.3;

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
    final correctYSide = playerServing ? y < 0 : y > 0;
    final correctXSide = serveFromLeft ? x > 0 : x < 0;
    return isInsideCourt(x, y) && correctYSide && correctXSide;
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
