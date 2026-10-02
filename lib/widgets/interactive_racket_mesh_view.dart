import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/paddle_item.dart';
import '../services/racket_3d_mesh_loader.dart';
import 'racket_3d_painter.dart';

/// Full-featured interactive 3D mesh viewer for the pickleball racket.
/// Supports smooth auto-rotation, 360° touch/mouse orbiting, pitch tilting,
/// and instant skin styling on all platforms without external WebViews.
class InteractiveRacketMeshView extends StatefulWidget {
  final PaddleItem paddle;
  final double height;

  const InteractiveRacketMeshView({
    super.key,
    required this.paddle,
    required this.height,
  });

  @override
  State<InteractiveRacketMeshView> createState() =>
      _InteractiveRacketMeshViewState();
}

class _InteractiveRacketMeshViewState extends State<InteractiveRacketMeshView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Racket3DMesh? _mesh;
  bool _isLoading = true;

  double _yaw = 0.0;
  double _pitch = 0.15; // Slight initial tilt for 3D depth
  bool _isUserDragging = false;
  bool _autoRotate = true;
  Timer? _resumeAutoRotateTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _animController.repeat();

    _loadMesh();
  }

  Future<void> _loadMesh() async {
    try {
      final mesh = await Racket3DMeshLoader.load();
      if (mounted) {
        setState(() {
          _mesh = mesh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTick() {
    if (_autoRotate && !_isUserDragging) {
      setState(() {
        _yaw += 0.018; // ~1 rad/sec rotation
        if (_yaw > math.pi * 2) {
          _yaw -= math.pi * 2;
        }
      });
    }
  }

  @override
  void dispose() {
    _resumeAutoRotateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isUserDragging = true;
      _resumeAutoRotateTimer?.cancel();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _yaw += details.delta.dx * 0.012;
      _pitch = (_pitch - details.delta.dy * 0.012).clamp(-math.pi / 3, math.pi / 3);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isUserDragging = false);
    _resumeAutoRotateTimer?.cancel();
    _resumeAutoRotateTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _autoRotate = true);
    });
  }

  void _resetOrientation() {
    setState(() {
      _yaw = 0.0;
      _pitch = 0.15;
      _autoRotate = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _mesh == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: widget.paddle.energyColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'INITIALIZING 3D MESH...',
              style: TextStyle(
                color: widget.paddle.energyColor.withValues(alpha: 0.8),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: Racket3DPainter(
                mesh: _mesh!,
                paddle: widget.paddle,
                yaw: _yaw,
                pitch: _pitch,
              ),
            ),
          ),

          // Interactive Drag Hint Pill (bottom-center)
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.paddle.energyColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.screen_rotation_alt_rounded,
                    size: 11,
                    color: widget.paddle.energyColor.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'DRAG TO ROTATE 360°',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reset Orientation Button (bottom-right)
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.restart_alt_rounded,
                size: 18,
                color: widget.paddle.energyColor.withValues(alpha: 0.7),
              ),
              tooltip: 'Reset 3D View',
              onPressed: _resetOrientation,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
