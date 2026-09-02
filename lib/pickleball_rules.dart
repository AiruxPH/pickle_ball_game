enum RallyPhase { botServe, playerServe, playerReturn, botReturn, openRally }

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
}
