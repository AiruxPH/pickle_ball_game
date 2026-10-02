import 'dart:ui';

import 'package:flame/components.dart';

import '../pickleball_flame_game.dart';
import '../settings_manager.dart';

/// Flame visual component for rendering the 3D projected pickleball,
/// its ground shadow, high-velocity motion trail, and perforations.
class BallVisualComponent extends Component {
  BallVisualComponent(this.game);

  final PickleballFlameGame game;
  final List<Offset> _trail = [];
  final List<double> _trailScales = [];

  @override
  void update(double dt) {
    super.update(dt);

    final simulation = game.simulation;
    final ballPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final ballCenter = Offset(
      (ballPoint.x + 1.0) / 2.0 * game.size.x,
      (ballPoint.y + 1.0) / 2.0 * game.size.y,
    );

    // Only add to trail if ball is moving fast enough and effects are enabled.
    if (SettingsManager().showEffects &&
        (simulation.ball.velocityX.abs() > 0.005 ||
            simulation.ball.velocityY.abs() > 0.005)) {
      _trail.add(ballCenter);
      _trailScales.add(ballPoint.scale * simulation.ballScale());
      if (_trail.length > 8) {
        _trail.removeAt(0);
        _trailScales.removeAt(0);
      }
    } else {
      if (_trail.isNotEmpty) {
        _trail.removeAt(0);
        _trailScales.removeAt(0);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final simulation = game.simulation;
    final shadowPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
    );
    final ballPoint = simulation.camera.project(
      x: simulation.ball.x,
      y: simulation.ball.y,
      elevation: simulation.ball.z,
    );
    final shadowCenter = Offset(
      (shadowPoint.x + 1.0) / 2.0 * game.size.x,
      (shadowPoint.y + 1.0) / 2.0 * game.size.y,
    );
    final ballCenter = Offset(
      (ballPoint.x + 1.0) / 2.0 * game.size.x,
      (ballPoint.y + 1.0) / 2.0 * game.size.y,
    );

    final depthScale = shadowPoint.scale;
    final shadowScale = depthScale * simulation.ballShadowScale();
    final ballScale = depthScale * simulation.ballScale();

    // Draw shadow
    final shadowPaint = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: 18 * shadowScale,
        height: 8 * shadowScale,
      ),
      shadowPaint,
    );

    // Draw trail
    for (int i = 0; i < _trail.length; i++) {
      final progress = (i + 1) / _trail.length;
      final opacity = progress * 0.34;
      final sizeMult = 0.35 + progress * 0.65;
      final trailPaint = Paint()
        ..color = Color.fromRGBO(216, 240, 106, opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(_trail[i], 8 * _trailScales[i] * sizeMult, trailPaint);
    }

    final glowPaint = Paint()
      ..color = const Color(0x66D8F06A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(ballCenter, 14 * ballScale, glowPaint);

    final ballPaint = Paint()
      ..shader = Gradient.radial(
        ballCenter.translate(-3 * ballScale, -3 * ballScale),
        11 * ballScale,
        [
          const Color(0xFFF4FF81),
          const Color(0xFFD4E157),
          const Color(0xFF9E9D24),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballCenter, 11 * ballScale, ballPaint);

    final outlinePaint = Paint()
      ..color = SettingsManager().highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xE6F8FFD0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (SettingsManager().highContrast ? 2.8 : 1.4) * ballScale;
    canvas.drawCircle(ballCenter, 11 * ballScale, outlinePaint);

    // A few high-contrast perforations keep the projectile readable as a
    // pickleball instead of a generic glowing orb.
    final holePaint = Paint()..color = const Color(0xAA76851D);
    canvas.drawCircle(
      ballCenter.translate(-3.2 * ballScale, -2.2 * ballScale),
      1.25 * ballScale,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter.translate(3.4 * ballScale, 1.6 * ballScale),
      1.05 * ballScale,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter.translate(-1.0 * ballScale, 4.0 * ballScale),
      0.9 * ballScale,
      holePaint,
    );
  }
}
