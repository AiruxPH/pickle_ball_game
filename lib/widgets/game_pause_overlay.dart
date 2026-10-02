import 'package:flutter/material.dart';

import 'angular_frame.dart';

/// Modal dialog for confirming destructive in-game actions like restarting or quitting.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (BuildContext ctx) => ConfirmationDialog(
        title: title,
        content: content,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AngularFrame(
        width: 310,
        cut: 16,
        accent: const Color(0xFFF59E0B),
        fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'YES',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylized pause menu button with custom icon, labels, and borders.
class PauseMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final Color? borderColor;

  const PauseMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen pause overlay for pausing, resuming, restarting, and quitting.
class GamePauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  const GamePauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Game paused',
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: AngularFrame(
            width: 290,
            cut: 18,
            accent: const Color(0xFFF59E0B),
            fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 28),
                PauseMenuButton(
                  icon: Icons.play_arrow,
                  label: 'RESUME',
                  color: const Color(0xFFF59E0B),
                  textColor: Colors.black,
                  onTap: onResume,
                ),
                const SizedBox(height: 12),
                PauseMenuButton(
                  icon: Icons.refresh,
                  label: 'RESTART',
                  color: Colors.transparent,
                  textColor: Colors.white,
                  borderColor: Colors.white54,
                  onTap: () {
                    ConfirmationDialog.show(
                      context: context,
                      title: 'Restart Match',
                      content:
                          'Are you sure you want to restart? Your current score will be lost.',
                      onConfirm: onRestart,
                    );
                  },
                ),
                const SizedBox(height: 12),
                PauseMenuButton(
                  icon: Icons.exit_to_app,
                  label: 'QUIT',
                  color: Colors.transparent,
                  textColor: const Color(0xFFE11D48),
                  borderColor: const Color(0xFFE11D48).withValues(alpha: 0.5),
                  onTap: () {
                    ConfirmationDialog.show(
                      context: context,
                      title: 'Quit Game',
                      content: 'Are you sure you want to quit to the main menu?',
                      onConfirm: onQuit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
