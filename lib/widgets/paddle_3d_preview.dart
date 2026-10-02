import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/draw_kinetic_paddle.dart';
import '../models/paddle_item.dart';
import 'interactive_racket_mesh_view.dart';

/// Interactive preview widget showing either the real-time 3D racket mesh
/// (`racket_for_pickleball.glb` hardware-accelerated raster) or the
/// orbital familiar canvas with animated strike physics.
class Paddle3DPreview extends StatefulWidget {
  final PaddleItem paddle;
  final double? height;

  const Paddle3DPreview({
    super.key,
    required this.paddle,
    this.height,
  });

  @override
  State<Paddle3DPreview> createState() => _Paddle3DPreviewState();
}

class _Paddle3DPreviewState extends State<Paddle3DPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _show3dMesh = true; // Defaults directly to the real 3D mesh across all platforms

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
          // Main Preview: Interactive 3D Mesh or Animated 2D Familiar
          if (_show3dMesh)
            InteractiveRacketMeshView(
              key: ValueKey('3d_mesh_${widget.paddle.id}'),
              paddle: widget.paddle,
              height: widget.height ?? 240,
            )
          else
            AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(double.infinity, widget.height ?? 240),
                  painter: _FamiliarPaddlePainter(
                    paddle: widget.paddle,
                    animTimer: _animController.value * 4.0,
                  ),
                );
              },
            ),

          // Platform Mode Switcher Button (3D Mesh / Familiar Canvas)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() => _show3dMesh = !_show3dMesh);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.paddle.energyColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _show3dMesh ? Icons.auto_awesome : Icons.view_in_ar,
                      color: widget.paddle.energyColor,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _show3dMesh ? 'VIEW FAMILIAR (2D)' : 'VIEW 3D MESH',
                      style: TextStyle(
                        color: widget.paddle.energyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
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
