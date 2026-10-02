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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 420;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AngularFrame(
          width: 310,
          cut: 16,
          accent: const Color(0xFFF59E0B),
          fillColors: const [Color(0xFF222930), Color(0xFF13171B)],
          padding: EdgeInsets.all(compact ? 14 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFFF59E0B),
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                content,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 12 : 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 14 : 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 18 : 24,
                        vertical: compact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 14,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 18 : 24,
                        vertical: compact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'YES',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
