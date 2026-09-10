enum MatchSide { player, bot }

enum MatchStatus { ready, playing, complete }

class MatchState {
  MatchState({
    this.playerScore = 0,
    this.botScore = 0,
    this.servingSide = MatchSide.bot,
    this.status = MatchStatus.ready,
  });

  static const int winningScore = 11;

  int playerScore;
  int botScore;
  MatchSide servingSide;
  MatchStatus status;

  bool get isComplete => status == MatchStatus.complete;

  void start() {
    if (!isComplete) {
      status = MatchStatus.playing;
    }
  }

  void reset() {
    playerScore = 0;
    botScore = 0;
    servingSide = MatchSide.bot;
    status = MatchStatus.ready;
  }

  void applyFault({required MatchSide faultSide}) {
    if (isComplete) return;

    if (faultSide == servingSide) {
      servingSide = _otherSide(servingSide);
    } else {
      _awardPointTo(_otherSide(faultSide));
    }

    if (_hasWinningScore) {
      status = MatchStatus.complete;
    }
  }

  void awardPointTo(MatchSide side) {
    if (isComplete) return;

    _awardPointTo(side);
    if (_hasWinningScore) {
      status = MatchStatus.complete;
    }
  }

  bool get _hasWinningScore {
    final highestScore = playerScore > botScore ? playerScore : botScore;
    return highestScore >= winningScore && (playerScore - botScore).abs() >= 2;
  }

  void _awardPointTo(MatchSide side) {
    if (side == MatchSide.player) {
      playerScore++;
    } else {
      botScore++;
    }
  }

  MatchSide _otherSide(MatchSide side) {
    return side == MatchSide.player ? MatchSide.bot : MatchSide.player;
  }
}