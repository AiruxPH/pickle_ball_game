import 'package:flutter/material.dart';

import 'angular_frame.dart';
import 'confirmation_dialog.dart';
import 'pause_menu_button.dart';

export 'confirmation_dialog.dart';
export 'pause_menu_button.dart';

/// Full-screen pause overlay for pausing, resuming, restarting, and quitting.
/// Automatically adapts its typography, padding, and constraints to any screen
/// size or aspect ratio without overflowing.
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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 420;
    final isSuperCompact = size.height < 320;

    return Semantics(
      label: 'Game paused',
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AngularFrame(
              width: isSuperCompact ? 260 : (isCompact ? 275 : 290),
              cut: isCompact ? 14 : 18,
              accent: const Color(0xFFF59E0B),
              fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
              padding: EdgeInsets.symmetric(
                vertical: isSuperCompact ? 14 : (isCompact ? 18 : 28),
                horizontal: isCompact ? 18 : 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAUSED',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B),
                      fontSize: isSuperCompact ? 22 : (isCompact ? 26 : 32),
                      fontWeight: FontWeight.w900,
                      letterSpacing: isCompact ? 2.5 : 4,
                    ),
                  ),
                  SizedBox(
                    height: isSuperCompact ? 12 : (isCompact ? 16 : 28),
                  ),
                  PauseMenuButton(
                    icon: Icons.play_arrow,
                    label: 'RESUME',
                    color: const Color(0xFFF59E0B),
                    textColor: Colors.black,
                    compact: isCompact,
                    onTap: onResume,
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                  PauseMenuButton(
                    icon: Icons.refresh,
                    label: 'RESTART',
                    color: Colors.transparent,
                    textColor: Colors.white,
                    borderColor: Colors.white54,
                    compact: isCompact,
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
                  SizedBox(height: isCompact ? 8 : 12),
                  PauseMenuButton(
                    icon: Icons.exit_to_app,
                    label: 'QUIT',
                    color: Colors.transparent,
                    textColor: const Color(0xFFE11D48),
                    borderColor: const Color(0xFFE11D48).withValues(alpha: 0.5),
                    compact: isCompact,
                    onTap: () {
                      ConfirmationDialog.show(
                        context: context,
                        title: 'Quit Game',
                        content:
                            'Are you sure you want to quit to the main menu?',
                        onConfirm: onQuit,
                      );
                    },
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
