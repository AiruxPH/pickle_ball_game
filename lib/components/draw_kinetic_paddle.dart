import 'dart:math' as math;
import 'dart:ui';

import '../models/paddle_item.dart';

/// Standalone rendering function for drawing the kinetic elongated paddle familiar,
/// its revolving orbit, aiming vector, and contact effects.
void drawKineticPaddle({
  required Canvas canvas,
  required Offset charCenter,
  required double scale,
  required int facingRow,
  required double animTimer,
  required bool isSwinging,
  required double swingProgress,
  required Offset ballScreenPos,
  required Color paddleFaceColor,
  required Color paddleRimColor,
  required Color energyColor,
  required Color sweetSpotColor,
  required PaddleDesign design,
}) {
  canvas.save();

  // Hand anchor relative to character center
  final Offset handOffset = switch (facingRow) {
    0 => Offset(16 * scale, -10 * scale), // Facing Up
    1 => Offset(-14 * scale, -8 * scale), // Facing Left
    2 => Offset(14 * scale, -6 * scale), // Facing Down
    _ => Offset(14 * scale, -8 * scale), // Facing Right
  };

  final handPos = charCenter + handOffset;

  // --- FAMILIAR REVOLVING ORBIT ---
  // The paddle orbits around the character like a magical companion/familiar.
  final orbitSpeed = switch (design) {
    PaddleDesign.lightning => 3.5,
    PaddleDesign.inferno => 2.9,
    PaddleDesign.sovereign => 2.15,
    PaddleDesign.cosmos => 1.75,
    PaddleDesign.industrial => 1.55,
    PaddleDesign.phantom => 2.35,
    PaddleDesign.tournament => 2.6,
  };
  final orbitAngle = animTimer * orbitSpeed;
  final orbitRadiusX = 28.0 * scale;
  final orbitRadiusY = 11.5 * scale; // Compressed in Y for isometric perspective
  final orbitCenterY = -12.0 * scale; // Torso / chest height

  final cosOrbit = math.cos(orbitAngle);
  final sinOrbit = math.sin(orbitAngle);
  final motionPhase = switch (design) {
    PaddleDesign.lightning => math.sin(animTimer * 13.0) * 0.9,
    PaddleDesign.inferno => math.sin(animTimer * 7.0) * 1.5,
    PaddleDesign.sovereign => math.sin(animTimer * 3.0) * 2.8,
    PaddleDesign.cosmos => math.sin(animTimer * 2.2) * 3.5,
    PaddleDesign.industrial => math.sin(animTimer * 5.0) * 0.8,
    PaddleDesign.phantom => math.sin(animTimer * 4.0) * 2.0,
    PaddleDesign.tournament => math.sin(animTimer * 5.0) * 2.2,
  };
  final familiarBob = motionPhase * scale;

  final orbitPos = charCenter +
      Offset(
        cosOrbit * orbitRadiusX,
        orbitCenterY + sinOrbit * orbitRadiusY + familiarBob,
      );

  // Dynamic lean/tilt as the familiar glides along its orbital ellipse
  final orbitTilt = -sinOrbit * 0.25;
  final familiarRestAngle = orbitTilt + (math.sin(animTimer * 3.5) * 0.08);

  // Depth scale effect: slightly larger when in front (+sinOrbit), smaller when behind (-sinOrbit)
  final depthScale = 1.0 + (sinOrbit * 0.12);

  Offset paddlePos;
  double paddleAngle;
  double flightCurve = 0.0;

  if (isSwinging && swingProgress > 0) {
    // Kinetic flight curve: 0.0 -> 1.0 (peak extension at ball) -> 0.0 (return)
    flightCurve = math.sin(swingProgress.clamp(0.0, 1.0) * math.pi);

    final diff = ballScreenPos - charCenter;
    final dist = diff.distance;

    // The sweet spot of the elongated paddle is located at the center of the blade
    // (-19 * scale along the local -Y axis).
    final sweetSpotOffset = 19.0 * scale;
    // Maximum reaching extension matches the character's arm reach.
    final maxReach = 58.0 * scale;
    final reachDist = (dist - sweetSpotOffset).clamp(0.0, maxReach);
    final targetPos =
        dist > 1.0 ? charCenter + (diff / dist) * reachDist : orbitPos;

    paddlePos = Offset.lerp(orbitPos, targetPos, flightCurve)!;

    // Angle to ball
    final aimAngle = math.atan2(diff.dy, diff.dx);
    // Align elongated blade (-Y in local space) directly towards the ball at contact
    final strikeAngle = aimAngle + math.pi / 2;
    final shortestAngleDiff =
        (strikeAngle - familiarRestAngle + math.pi) % (math.pi * 2) - math.pi;
    final followThrough = (swingProgress - 0.5) * 0.4;
    paddleAngle =
        familiarRestAngle + shortestAngleDiff * flightCurve + followThrough;
  } else {
    paddlePos = orbitPos;
    paddleAngle = familiarRestAngle;
  }

  // Draw Familiar Energy Aura & Visual Accents
  if (flightCurve > 0.05) {
    // Energy Tether / Trail from Hand to Flying Familiar
    final tetherPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.55 * flightCurve)
      ..strokeWidth = 3.0 * scale
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(handPos, paddlePos, tetherPaint);

    final tetherCore = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * flightCurve)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(handPos, paddlePos, tetherCore);

    // Energy Burst / Shockwave around paddle on contact
    final burstPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.45 * flightCurve)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    // Pulse shockwave centered right at the sweet spot
    final sweetSpotWorld = paddlePos +
        Offset(
          math.sin(paddleAngle) * (19 * scale),
          -math.cos(paddleAngle) * (19 * scale),
        );
    canvas.drawCircle(sweetSpotWorld, 20 * scale * flightCurve, burstPaint);
  } else {
    // Faint ethereal orbit ring around the player's waist
    final ringPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: charCenter.translate(0, orbitCenterY),
        width: orbitRadiusX * 2,
        height: orbitRadiusY * 2,
      ),
      ringPaint,
    );

    // Stardust trail motes revolving behind the familiar
    final trailPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 1; i <= 3; i++) {
      final prevAngle = orbitAngle - (i * 0.22);
      final prevPos = charCenter +
          Offset(
            math.cos(prevAngle) * orbitRadiusX,
            orbitCenterY + math.sin(prevAngle) * orbitRadiusY + familiarBob,
          );
      trailPaint.color = energyColor.withValues(alpha: 0.35 / i);
      canvas.drawCircle(prevPos, (2.2 - i * 0.4) * scale, trailPaint);
    }

    // Subtle levitation shadow underneath floating familiar
    final auraPaint = Paint()
      ..color = energyColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: paddlePos.translate(0, 16 * scale * depthScale),
        width: 15 * scale * depthScale,
        height: 5 * scale * depthScale,
      ),
      auraPaint,
    );
  }

  // Draw Paddle Body at paddlePos rotated by paddleAngle
  canvas.translate(paddlePos.dx, paddlePos.dy);
  canvas.rotate(paddleAngle);
  if (flightCurve <= 0.05) {
    canvas.scale(depthScale, depthScale);
  }

  // 1. Paddle Handle / Grip (Elongated pro handle)
  final gripPaint = Paint()
    ..color = const Color(0xFF1E293B) // Dark graphite grip
    ..style = PaintingStyle.fill;
  final gripWrapPaint = Paint()
    ..color = const Color(0xFFF1F5F9) // Premium white perforated overgrip
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3 * scale;
  final gripRect = Rect.fromCenter(
    center: Offset(0, 7.5 * scale),
    width: 3.8 * scale,
    height: 15.0 * scale,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(gripRect, Radius.circular(1.8 * scale)),
    gripPaint,
  );
  // Butt Cap
  final buttCapPaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 15.2 * scale),
        width: 4.8 * scale,
        height: 2.2 * scale,
      ),
      Radius.circular(1.0 * scale),
    ),
    buttCapPaint,
  );
  // Diagonal wrap ridges across the grip
  for (var i = 0; i < 4; i++) {
    final y = 2.0 * scale + i * 3.2 * scale;
    canvas.drawLine(
      Offset(-1.8 * scale, y),
      Offset(1.8 * scale, y + 2.0 * scale),
      gripWrapPaint,
    );
  }

  // Tapered Throat / Neck collar connecting handle to blade
  final throatPaint = Paint()
    ..color = paddleRimColor
    ..style = PaintingStyle.fill;
  final throatPath = Path()
    ..moveTo(-1.9 * scale, 0)
    ..lineTo(-4.5 * scale, -4.5 * scale)
    ..lineTo(4.5 * scale, -4.5 * scale)
    ..lineTo(1.9 * scale, 0)
    ..close();
  canvas.drawPath(throatPath, throatPaint);

  // 2. Elongated Paddle Edge Guard (Outer Rim)
  final rimPaint = Paint()
    ..color = paddleRimColor
    ..style = PaintingStyle.fill;
  final bladeWidth = switch (design) {
    PaddleDesign.inferno => 17.5,
    PaddleDesign.sovereign => 14.0,
    PaddleDesign.cosmos => 16.8,
    PaddleDesign.industrial => 18.0,
    PaddleDesign.phantom => 13.5,
    _ => 15.0,
  };
  final bladeHeight = switch (design) {
    PaddleDesign.lightning => 34.0,
    PaddleDesign.sovereign => 33.5,
    PaddleDesign.industrial => 28.0,
    PaddleDesign.phantom => 35.0,
    _ => 31.0,
  };
  final cornerRadius = switch (design) {
    PaddleDesign.lightning => 3.0,
    PaddleDesign.sovereign => 2.0,
    PaddleDesign.industrial => 2.5,
    PaddleDesign.cosmos => 8.0,
    _ => 5.5,
  };
  final paddleRim = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: bladeWidth * scale,
      height: bladeHeight * scale,
    ),
    Radius.circular(cornerRadius * scale),
  );
  canvas.drawRRect(paddleRim, rimPaint);

  // 3. Elongated Paddle Face (Raw Carbon / Honeycomb Face)
  final facePaint = Paint()
    ..color = paddleFaceColor
    ..style = PaintingStyle.fill;
  final paddleFace = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: (bladeWidth - 2.4) * scale,
      height: (bladeHeight - 2.5) * scale,
    ),
    Radius.circular(math.max(1.2, cornerRadius - 1.4) * scale),
  );
  canvas.drawRRect(paddleFace, facePaint);

  _drawDesignMotif(
    canvas,
    design: design,
    scale: scale,
    energyColor: energyColor,
    sweetSpotColor: sweetSpotColor,
    bladeWidth: bladeWidth,
    bladeHeight: bladeHeight,
  );

  // Subtle carbon fiber micro-texture stripes
  final texturePaint = Paint()
    ..color = const Color(0x18000000)
    ..strokeWidth = 0.8 * scale;
  for (var i = -4; i <= 4; i++) {
    final y = -19 * scale + i * 3.0 * scale;
    canvas.drawLine(
      Offset(-5.0 * scale, y),
      Offset(5.0 * scale, y),
      texturePaint,
    );
  }

  // 4. Elongated Sweet Spot Core & Target Crosshair Graphic
  final sweetSpotGlow = Paint()
    ..color = sweetSpotColor.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0 * scale;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 7.5 * scale,
      height: 12.0 * scale,
    ),
    sweetSpotGlow,
  );

  final sweetSpotPaint = Paint()
    ..color = sweetSpotColor
    ..style = PaintingStyle.fill;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, -19 * scale),
      width: 4.5 * scale,
      height: 7.5 * scale,
    ),
    sweetSpotPaint,
  );

  final corePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(Offset(0, -19 * scale), 1.4 * scale, corePaint);

  // Dynamic Chevron speed stripes near the top of the elongated paddle
  final chevronPaint = Paint()
    ..color = sweetSpotColor.withValues(alpha: 0.6)
    ..strokeWidth = 1.0 * scale
    ..style = PaintingStyle.stroke;
  final c1 = Path()
    ..moveTo(-3.5 * scale, -29 * scale)
    ..lineTo(0, -31.5 * scale)
    ..lineTo(3.5 * scale, -29 * scale);
  final c2 = Path()
    ..moveTo(-2.5 * scale, -26.5 * scale)
    ..lineTo(0, -28.5 * scale)
    ..lineTo(2.5 * scale, -26.5 * scale);
  canvas.drawPath(c1, chevronPaint);
  canvas.drawPath(c2, chevronPaint);

  canvas.restore();
}

void _drawDesignMotif(
  Canvas canvas, {
  required PaddleDesign design,
  required double scale,
  required Color energyColor,
  required Color sweetSpotColor,
  required double bladeWidth,
  required double bladeHeight,
}) {
  final paint = Paint()
    ..color = sweetSpotColor.withValues(alpha: 0.65)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1 * scale;
  final center = Offset(0, -19 * scale);

  switch (design) {
    case PaddleDesign.tournament:
      canvas.drawLine(Offset(-4 * scale, -19 * scale), Offset(4 * scale, -19 * scale), paint);
      canvas.drawLine(Offset(0, -23 * scale), Offset(0, -15 * scale), paint);
      break;
    case PaddleDesign.lightning:
      final bolt = Path()
        ..moveTo(2 * scale, (-19 - bladeHeight * .36) * scale)
        ..lineTo(-3 * scale, -20 * scale)
        ..lineTo(1 * scale, -20 * scale)
        ..lineTo(-2 * scale, (-19 + bladeHeight * .36) * scale);
      canvas.drawPath(bolt, paint..strokeWidth = 2.0 * scale);
      break;
    case PaddleDesign.inferno:
      final flame = Path()
        ..moveTo(0, (-19 - bladeHeight * .34) * scale)
        ..quadraticBezierTo(7 * scale, -18 * scale, 0, (-19 + bladeHeight * .34) * scale)
        ..quadraticBezierTo(-6 * scale, -19 * scale, 0, (-19 - bladeHeight * .34) * scale);
      canvas.drawPath(flame, paint);
      break;
    case PaddleDesign.sovereign:
      final crown = Path()
        ..moveTo(-5 * scale, -17 * scale)
        ..lineTo(-4 * scale, -24 * scale)
        ..lineTo(0, -20 * scale)
        ..lineTo(4 * scale, -24 * scale)
        ..lineTo(5 * scale, -17 * scale);
      canvas.drawPath(crown, paint..strokeWidth = 1.5 * scale);
      break;
    case PaddleDesign.cosmos:
      canvas.drawCircle(center, 5.2 * scale, paint);
      canvas.drawOval(Rect.fromCenter(center: center, width: 13 * scale, height: 4 * scale), paint);
      canvas.drawCircle(Offset(5.5 * scale, -19 * scale), 1.2 * scale, Paint()..color = energyColor);
      break;
    case PaddleDesign.industrial:
      canvas.drawRect(Rect.fromCenter(center: center, width: 9 * scale, height: 12 * scale), paint);
      for (final x in [-4.5, 4.5]) {
        for (final y in [-6.0, 6.0]) {
          canvas.drawCircle(center + Offset(x * scale, y * scale), 1.0 * scale, Paint()..color = sweetSpotColor);
        }
      }
      break;
    case PaddleDesign.phantom:
      final slash = Path()
        ..moveTo(-bladeWidth * .3 * scale, (-19 + bladeHeight * .3) * scale)
        ..quadraticBezierTo(0, -25 * scale, bladeWidth * .3 * scale, (-19 - bladeHeight * .3) * scale);
      canvas.drawPath(slash, paint..strokeWidth = 1.8 * scale);
      break;
  }
}
