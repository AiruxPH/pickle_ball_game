import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Flame VFX component for player/bot dash movements.
class DashEffectComponent extends Component {
  DashEffectComponent({
    required this.center,
    required this.scale,
    required this.isPlayer,
  });

  final Offset center;
  final double scale;
  final bool isPlayer;

  double _lifetime = 0.0;
  static const double _maxLifetime = 0.30;

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / _maxLifetime).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress) * 200).round().clamp(0, 255);
    final color = isPlayer ? const Color(0xFF00B0FF) : const Color(0xFFFF5252);

    // Expanding ring
    final ringRadius = 22.0 * scale + progress * 38.0 * scale;
    final ringPaint = Paint()
      ..color = color.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * (1.0 - progress) * scale;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Speed streaks
    final streakPaint = Paint()
      ..color = color.withAlpha((alpha * 0.6).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 + 20) * math.pi / 180;
      final len = (20.0 + i * 8.0) * scale * (1.0 - progress * 0.5);
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * 20 * scale,
          center.dy + math.sin(angle) * 20 * scale,
        ),
        Offset(
          center.dx + math.cos(angle) * (20 * scale + len),
          center.dy + math.sin(angle) * (20 * scale + len),
        ),
        streakPaint,
      );
    }
  }
}
