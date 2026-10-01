import 'package:flutter/material.dart';

import '../bot_agent.dart';
import '../theme/app_theme.dart';
import 'angular_frame.dart';
import 'figma_game_frames.dart';

class MatchScoreboard extends StatelessWidget {
  const MatchScoreboard({
    super.key,
    required this.leftLabel,
    required this.leftScore,
    required this.leftColor,
    required this.rightLabel,
    required this.rightScore,
    required this.rightColor,
    required this.leftServing,
    required this.rightServing,
    required this.rallyLength,
  });

  final String leftLabel;
  final int leftScore;
  final Color leftColor;
  final String rightLabel;
  final int rightScore;
  final Color rightColor;
  final bool leftServing;
  final bool rightServing;
  final int rallyLength;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: AngularFrame(
        accent: AppTheme.accentGold,
        cut: 10,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScoreSide(
              label: leftLabel,
              score: leftScore,
              color: leftColor,
              serving: leftServing,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: AppTheme.ink.withValues(alpha: 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RALLY',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '$rallyLength',
                    style: const TextStyle(
                      color: AppTheme.accentLime,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _ScoreSide(
              label: rightLabel,
              score: rightScore,
              color: rightColor,
              serving: rightServing,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({
    required this.label,
    required this.score,
    required this.color,
    required this.serving,
  });

  final String label;
  final int score;
  final Color color;
  final bool serving;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '$label score $score${serving ? ', serving' : ''}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 104),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (serving) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.accentLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentLime.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              '$label: $score',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpectatorBotCard extends StatelessWidget {
  const SpectatorBotCard({
    super.key,
    required this.agent,
    required this.label,
    required this.color,
    required this.panelStyle,
    required this.isIncoming,
  });

  final BotAgent agent;
  final String label;
  final Color color;
  final GamePanelStyle panelStyle;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: FigmaGamePanel(
        style: panelStyle,
        title: label,
        titlePadding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
        contentPadding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 3, height: 18, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    agent.personality.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              agent.isDashing
                  ? 'DASHING'
                  : isIncoming
                  ? 'READING BALL'
                  : 'RECOVERING',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
