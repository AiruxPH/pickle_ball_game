import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A responsive, asymmetrical arcade frame with clipped corners and layered
/// bevels. The silhouette is intentionally original and scales without image
/// assets, so it stays crisp on phones, desktop, and web.
class AngularFrame extends StatelessWidget {
  const AngularFrame({
    super.key,
    required this.child,
    this.accent = AppTheme.accentCyan,
    this.padding = const EdgeInsets.all(16),
    this.fillColors = const [AppTheme.surfaceRaised, AppTheme.panelBg],
    this.cut = 13,
    this.shadow = true,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final List<Color> fillColors;
  final double cut;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AngularFramePainter(
        accent: accent,
        fillColors: fillColors,
        cut: cut,
        shadow: shadow,
      ),
      child: ClipPath(
        clipper: _AngularFrameClipper(cut),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

Path _angularPath(Size size, double requestedCut) {
  final cut = requestedCut.clamp(5.0, size.shortestSide * 0.24);
  final smallCut = cut * 0.48;
  return Path()
    ..moveTo(cut, 1)
    ..lineTo(size.width - cut * 1.8, 1)
    ..lineTo(size.width - cut, smallCut)
    ..lineTo(size.width - 1, cut * 0.82)
    ..lineTo(size.width - smallCut, size.height - cut)
    ..lineTo(size.width - cut * 1.35, size.height - 2)
    ..lineTo(cut * 1.55, size.height - 2)
    ..lineTo(cut * 0.72, size.height - smallCut)
    ..lineTo(1, size.height - cut * 1.15)
    ..lineTo(smallCut, size.height * 0.54)
    ..lineTo(1, cut)
    ..close();
}

class _AngularFrameClipper extends CustomClipper<Path> {
  const _AngularFrameClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) => _angularPath(size, cut);

  @override
  bool shouldReclip(_AngularFrameClipper oldClipper) => oldClipper.cut != cut;
}

class _AngularFramePainter extends CustomPainter {
  const _AngularFramePainter({
    required this.accent,
    required this.fillColors,
    required this.cut,
    required this.shadow,
  });

  final Color accent;
  final List<Color> fillColors;
  final double cut;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = _angularPath(size, cut);

    if (shadow) {
      canvas.save();
      canvas.translate(0, 5);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fillColors,
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xDD02070C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final topBevel = Path()
      ..moveTo(cut + 3, 4)
      ..lineTo(size.width - cut * 1.85, 4)
      ..lineTo(size.width - cut - 2, cut * 0.48 + 2);
    canvas.drawPath(
      topBevel,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final lowerNotch = Path()
      ..moveTo(size.width * 0.36, size.height - 2)
      ..lineTo(size.width * 0.43, size.height - 7)
      ..lineTo(size.width * 0.52, size.height - 2);
    canvas.drawPath(
      lowerNotch,
      Paint()
        ..color = accent.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_AngularFramePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.fillColors != fillColors ||
        oldDelegate.cut != cut ||
        oldDelegate.shadow != shadow;
  }
}
