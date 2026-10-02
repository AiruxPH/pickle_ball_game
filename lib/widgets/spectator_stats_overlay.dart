import 'package:flutter/material.dart';

import '../game_simulation.dart';
import '../theme/app_theme.dart';
import 'match_hud.dart';

/// Top-right live indicator and bot stats overlay displayed during spectator mode.
class SpectatorStatsOverlay extends StatelessWidget {
  final GameSimulation simulation;

  const SpectatorStatsOverlay({
    super.key,
    required this.simulation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: AppTheme.panel(
            accent: AppTheme.danger,
            radius: AppTheme.radiusSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'LIVE  •  SPECTATE',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${simulation.ballSpeed.toStringAsFixed(0)} MPH',
                style: const TextStyle(
                  color: AppTheme.accentLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpectatorBotCard(
              agent: simulation.topBotAgent,
              label: 'TOP BOT',
              color: AppTheme.teamCpu,
              isIncoming: simulation.ball.velocityY < 0,
            ),
            const SizedBox(width: 8),
            SpectatorBotCard(
              agent: simulation.bottomBotAgent,
              label: 'BOTTOM BOT',
              color: AppTheme.teamPlayer,
              isIncoming: simulation.ball.velocityY > 0,
            ),
          ],
        ),
      ],
    );
  }
}
