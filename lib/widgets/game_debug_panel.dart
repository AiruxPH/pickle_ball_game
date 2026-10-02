import 'package:flutter/material.dart';

import '../game_debug_config.dart';

/// Overlay panel providing sandbox and debug controls for hitboxes, AI toggles,
/// game speed, and score fast-forwarding.
class GameDebugPanel extends StatelessWidget {
  final VoidCallback onFastForwardScore;
  final VoidCallback onConfigChanged;

  const GameDebugPanel({
    super.key,
    required this.onFastForwardScore,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 8,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SANDBOX CONTROLS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Show Hitboxes',
                  style: TextStyle(color: Colors.white),
                ),
                value: GameDebugConfig.showHitboxes,
                onChanged: (val) {
                  GameDebugConfig.showHitboxes = val;
                  onConfigChanged();
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Freeze AI',
                  style: TextStyle(color: Colors.white),
                ),
                value: GameDebugConfig.freezeAI,
                onChanged: (val) {
                  GameDebugConfig.freezeAI = val;
                  onConfigChanged();
                },
              ),
              Text(
                'Speed: ${GameDebugConfig.gameSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                min: 0.0,
                max: 2.0,
                divisions: 20,
                value: GameDebugConfig.gameSpeed,
                onChanged: (val) {
                  GameDebugConfig.gameSpeed = val;
                  onConfigChanged();
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Bypass Kitchen Rules',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                value: GameDebugConfig.bypassKitchenRules,
                onChanged: (val) {
                  GameDebugConfig.bypassKitchenRules = val;
                  onConfigChanged();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onFastForwardScore,
                  child: const Text('Fast Forward (10-10)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
