import 'package:flutter/material.dart';

class BotRenderer extends StatelessWidget {
  const BotRenderer({
    required this.alignment,
    required this.scale,
    super.key,
  });

  final Alignment alignment;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
          child: const Icon(Icons.sports_tennis, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class BallRenderer extends StatelessWidget {
  const BallRenderer({
    required this.shadowAlignment,
    required this.ballAlignment,
    required this.shadowScale,
    required this.ballScale,
    super.key,
  });

  final Alignment shadowAlignment;
  final Alignment ballAlignment;
  final double shadowScale;
  final double ballScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: shadowAlignment,
          child: Transform.scale(
            scale: shadowScale,
            child: Container(
              width: 18,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Align(
          alignment: ballAlignment,
          child: Transform.scale(
            scale: ballScale,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFD4E157),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlayerRenderer extends StatelessWidget {
  const PlayerRenderer({
    required this.alignment,
    required this.scale,
    required this.isSwinging,
    super.key,
  });

  final Alignment alignment;
  final double scale;
  final bool isSwinging;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),
            Positioned(
              right: -20,
              top: isSwinging ? -15 : 5,
              child: Transform.rotate(
                angle: isSwinging ? -0.8 : 0.4,
                child: Container(
                  width: 14,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSwinging ? Colors.orangeAccent : Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black87, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}