import 'dart:ui';

import 'package:flame/components.dart';

/// Flame VFX component for ball ground bounces.
class BounceEffectComponent extends Component {
  BounceEffectComponent({required this.center, required this.scale});

  final Offset center;
  final double scale;
  double _lifetime = 0;
  static const double _maxLifetime = 0.28;

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / _maxLifetime).clamp(0.0, 1.0);
    final alpha = ((1 - progress) * 150).round().clamp(0, 255);
    final radius = (8 + progress * 25) * scale;
    final ringPaint = Paint()
      ..color = const Color(0xFFD8F06A).withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.4 - progress) * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2.2,
        height: radius * 0.8,
      ),
      ringPaint,
    );
  }
}
