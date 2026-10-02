import 'package:flutter/material.dart';

import '../game_simulation.dart';
import '../theme/app_theme.dart';
import 'angular_frame.dart';

/// Interactive practice facility HUD showing current drill, streak, target points,
/// and instant ball feeding controls.
class PracticeHud extends StatelessWidget {
  const PracticeHud({
    super.key,
    required this.simulation,
    required this.onLaunchBall,
    required this.onOpenDrillSettings,
    required this.onCycleDrill,
  });

  final GameSimulation simulation;
  final VoidCallback onLaunchBall;
  final VoidCallback onOpenDrillSettings;
  final VoidCallback onCycleDrill;

  String _drillLabel(PracticeDrill drill) => switch (drill) {
    PracticeDrill.dinks => 'DINKS',
    PracticeDrill.drives => 'DRIVES',
    PracticeDrill.lobs => 'LOBS',
    PracticeDrill.random => 'RANDOM',
  };

  IconData _drillIcon(PracticeDrill drill) => switch (drill) {
    PracticeDrill.dinks => Icons.arrow_downward,
    PracticeDrill.drives => Icons.flash_on,
    PracticeDrill.lobs => Icons.arrow_upward,
    PracticeDrill.random => Icons.shuffle,
  };

  @override
  Widget build(BuildContext context) {
    final drill = simulation.practiceDrill;
    final streak = simulation.practiceStreak;
    final bestStreak = simulation.practiceBestStreak;
    final score = simulation.practiceScore;
    final target = simulation.activeTarget;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: AngularFrame(
        cut: 14,
        accent: AppTheme.accentLime,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        fillColors: const [Color(0xEE1E242B), Color(0xEE12161A)],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drill Selection Chip (Tappable to cycle)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onCycleDrill,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.accentLime.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_drillIcon(drill), size: 16, color: AppTheme.accentLime),
                    const SizedBox(width: 6),
                    Text(
                      _drillLabel(drill),
                      style: const TextStyle(
                        color: AppTheme.accentLime,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 12),

            // Streak & Best
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STREAK: $streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'BEST: $bestStreak',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 12),

            // Target Zone & Score
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.track_changes, size: 18, color: AppTheme.accentCyan),
                const SizedBox(width: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score PTS',
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      target.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Manual Launch / Feed Ball Button
            ElevatedButton.icon(
              onPressed: onLaunchBall,
              icon: const Icon(Icons.sports_tennis, size: 16),
              label: const Text(
                'FEED BALL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentLime,
                foregroundColor: AppTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
            ),

            const SizedBox(width: 8),

            // Drill Settings Button
            IconButton(
              tooltip: 'Practice Drill Settings',
              onPressed: onOpenDrillSettings,
              icon: const Icon(Icons.tune, size: 18, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drill settings dialog using AngularFrame.
class PracticeDrillsDialog extends StatelessWidget {
  const PracticeDrillsDialog({
    super.key,
    required this.simulation,
    required this.onDrillChanged,
    required this.onIntervalChanged,
    required this.onAutoFeedChanged,
    required this.onResetStats,
  });

  final GameSimulation simulation;
  final ValueChanged<PracticeDrill> onDrillChanged;
  final ValueChanged<double> onIntervalChanged;
  final ValueChanged<bool> onAutoFeedChanged;
  final VoidCallback onResetStats;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AngularFrame(
        width: 360,
        cut: 16,
        accent: AppTheme.accentLime,
        fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: AppTheme.accentLime, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'PRACTICE DRILLS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'DRILL TYPE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PracticeDrill.values.map((d) {
                final isSelected = simulation.practiceDrill == d;
                final label = switch (d) {
                  PracticeDrill.dinks => 'Dinks',
                  PracticeDrill.drives => 'Drives',
                  PracticeDrill.lobs => 'Lobs',
                  PracticeDrill.random => 'Random',
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: AppTheme.accentLime,
                  backgroundColor: const Color(0xFF1E242B),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.ink : Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      onDrillChanged(d);
                      (context as Element).markNeedsBuild();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            const Text(
              'FEED MODE & SPEED',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    simulation.practiceAutoFeed
                        ? 'Auto Feed (${simulation.practiceFeedIntervalSeconds.toStringAsFixed(1)}s)'
                        : 'Manual Feed Only',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Switch(
                  value: simulation.practiceAutoFeed,
                  activeThumbColor: AppTheme.accentLime,
                  onChanged: (val) {
                    onAutoFeedChanged(val);
                    (context as Element).markNeedsBuild();
                  },
                ),
              ],
            ),
            if (simulation.practiceAutoFeed) ...[
              Slider(
                value: simulation.practiceFeedIntervalSeconds,
                min: 1.5,
                max: 4.5,
                divisions: 6,
                activeColor: AppTheme.accentLime,
                inactiveColor: Colors.white12,
                label: '${simulation.practiceFeedIntervalSeconds.toStringAsFixed(1)}s',
                onChanged: (val) {
                  onIntervalChanged(val);
                  (context as Element).markNeedsBuild();
                },
              ),
            ],

            const Divider(color: Colors.white12, height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    onResetStats();
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white60),
                  label: const Text(
                    'Reset Score & Streak',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentLime,
                    foregroundColor: AppTheme.ink,
                  ),
                  child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
