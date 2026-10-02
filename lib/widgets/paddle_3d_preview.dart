import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../components/draw_kinetic_paddle.dart';
import '../models/paddle_item.dart';

/// Interactive preview widget showing either the 3D GLTF/GLB model (`racket_for_pickleball.glb`)
/// or a real-time rendered kinetic familiar canvas showing the paddle's colors, orbit, and energy effects.
class Paddle3DPreview extends StatefulWidget {
  final PaddleItem paddle;
  final double height;

  const Paddle3DPreview({
    super.key,
    required this.paddle,
    this.height = 240,
  });

  @override
  State<Paddle3DPreview> createState() => _Paddle3DPreviewState();
}

class _Paddle3DPreviewState extends State<Paddle3DPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _prefer3dModel = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.paddle.energyColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.paddle.energyColor.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Content: 3D Model viewer or Animated Familiar Canvas
          if (_prefer3dModel)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: ModelViewer(
                key: ValueKey('model_${widget.paddle.id}'),
                src: 'assets/models/racket_for_pickleball.glb',
                alt: '3D Pickleball Racket Model',
                autoRotate: true,
                autoRotateDelay: 0,
                rotationPerSecond: '30deg',
                cameraControls: true,
                backgroundColor: Colors.transparent,
                shadowIntensity: 0.8,
                exposure: 1.1,
              ),
            )
          else
            AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(double.infinity, widget.height),
                  painter: _FamiliarPaddlePainter(
                    paddle: widget.paddle,
                    animTimer: _animController.value * 4.0,
                  ),
                );
              },
            ),

          // Platform Mode Switcher Button (3D Model / Familiar Canvas)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() => _prefer3dModel = !_prefer3dModel);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.paddle.energyColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _prefer3dModel ? Icons.auto_awesome : Icons.view_in_ar,
                      color: widget.paddle.energyColor,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _prefer3dModel ? 'VIEW FAMILIAR' : 'VIEW 3D MESH',
                      style: TextStyle(
                        color: widget.paddle.energyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamiliarPaddlePainter extends CustomPainter {
  final PaddleItem paddle;
  final double animTimer;

  _FamiliarPaddlePainter({
    required this.paddle,
    required this.animTimer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final scale = (size.height / 150).clamp(1.2, 1.8);

    // Simulated contact ball for interactive strike showcase
    final ballPos = center +
        Offset(
          math.sin(animTimer * 2.0) * 35 * scale,
          -45 * scale,
        );

    drawKineticPaddle(
      canvas: canvas,
      charCenter: center,
      scale: scale,
      facingRow: 2,
      animTimer: animTimer,
      isSwinging: false,
      swingProgress: 0.0,
      ballScreenPos: ballPos,
      paddleFaceColor: paddle.paddleFaceColor,
      paddleRimColor: paddle.paddleRimColor,
      energyColor: paddle.energyColor,
      sweetSpotColor: paddle.sweetSpotColor,
    );
  }

  @override
  bool shouldRepaint(covariant _FamiliarPaddlePainter oldDelegate) {
    return oldDelegate.animTimer != animTimer || oldDelegate.paddle.id != paddle.id;
  }
}
