import 'package:flutter/material.dart';

class AbstractBlobPainter extends CustomPainter {
  final double animationValue;

  AbstractBlobPainter({this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = const Color(0xFF0B132B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw some glowing abstract blobs
    final blobPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF18FFFF).withValues(alpha: 0.15),
          const Color(0xFF009688).withValues(alpha: 0.05),
          const Color(0xFF000000).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.3), radius: size.height * 0.8));

    final blobPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF009688).withValues(alpha: 0.15),
          const Color(0xFF18FFFF).withValues(alpha: 0.05),
          const Color(0xFF000000).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.8), radius: size.height * 0.7));

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), size.height * 0.8, blobPaint1);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), size.height * 0.7, blobPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  // If we want to animate it later, we can use the ticker.
  // For now, static is fine to save resources.
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AbstractBlobPainter(),
      size: Size.infinite,
    );
  }
}
