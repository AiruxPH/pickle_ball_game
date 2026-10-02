import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/paddle_item.dart';
import '../services/racket_3d_mesh_loader.dart';

/// Hardware-accelerated 3D custom painter that projects and shades the
/// pickleball racket mesh with perspective, real-time lighting, and custom skin themes.
class Racket3DPainter extends CustomPainter {
  final Racket3DMesh mesh;
  final PaddleItem paddle;
  final double yaw; // Rotation around Y-axis (radians)
  final double pitch; // Rotation around X-axis (radians)
  final double roll; // Rotation around Z-axis (radians)
  final double zoom;

  Racket3DPainter({
    required this.mesh,
    required this.paddle,
    required this.yaw,
    required this.pitch,
    this.roll = 0.0,
    this.zoom = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final viewScale = (math.min(size.width, size.height) * 0.44) * zoom;

    // Rotation matrices
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final cosR = math.cos(roll);
    final sinR = math.sin(roll);

    // Directional light vector pointing towards the racket from top-front-right
    const lx = 0.35;
    const ly = 0.55;
    const lz = 0.76; // Normalized [0.35, 0.55, 0.76]

    // Floor contact shadow
    final shadowScale = (viewScale * 0.75) * (1.0 - (sinP.abs() * 0.25));
    final shadowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx, center.dy + viewScale * 0.95),
        shadowScale,
        [
          paddle.energyColor.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + viewScale * 0.95),
        width: shadowScale * 1.5,
        height: shadowScale * 0.35,
      ),
      shadowPaint,
    );

    // Camera distance for perspective projection
    const camDist = 3.6;

    // Render each mesh part (Blade, Grip, Rim)
    for (final part in mesh.parts) {
      final vCount = part.vertexCount;
      final verts = part.vertices;
      final projectedPoints = <Offset>[];
      final vertexColors = <Color>[];

      // Base colors per part
      final Color baseColor;
      final double partShininess;
      if (part.name == 'blade') {
        baseColor = paddle.paddleFaceColor;
        partShininess = 24.0;
      } else if (part.name == 'grip') {
        baseColor = const Color(0xFF1E293B); // Dark tactical grip
        partShininess = 8.0;
      } else {
        baseColor = paddle.paddleRimColor;
        partShininess = 16.0;
      }

      final rBase = (baseColor.r * 255).round();
      final gBase = (baseColor.g * 255).round();
      final bBase = (baseColor.b * 255).round();

      for (int i = 0; i < vCount; i++) {
        final idx = i * 6;
        final isHead = part.name == 'blade' || part.name == 'rim';
        final profile = _profileScale(paddle.resolvedDesign);
        final x0 = verts[idx] * (isHead ? profile.$1 : 1.0);
        final y0 = verts[idx + 1] * (isHead ? profile.$2 : 1.0);
        final z0 = verts[idx + 2];
        final nx0 = verts[idx + 3];
        final ny0 = verts[idx + 4];
        final nz0 = verts[idx + 5];

        // 1. Yaw rotation (around Y)
        final x1 = x0 * cosY + z0 * sinY;
        final y1 = y0;
        final z1 = -x0 * sinY + z0 * cosY;

        final nx1 = nx0 * cosY + nz0 * sinY;
        final ny1 = ny0;
        final nz1 = -nx0 * sinY + nz0 * cosY;

        // 2. Pitch rotation (around X)
        final x2 = x1;
        final y2 = y1 * cosP - z1 * sinP;
        final z2 = y1 * sinP + z1 * cosP;

        final nx2 = nx1;
        final ny2 = ny1 * cosP - nz1 * sinP;
        final nz2 = ny1 * sinP + nz1 * cosP;

        // 3. Roll rotation (around Z)
        final x3 = x2 * cosR - y2 * sinR;
        final y3 = x2 * sinR + y2 * cosR;
        final z3 = z2;

        final nx3 = nx2 * cosR - ny2 * sinR;
        final ny3 = nx2 * sinR + ny2 * cosR;
        final nz3 = nz2;

        // Perspective projection
        final w = camDist / (camDist - z3);
        final sx = center.dx + x3 * w * viewScale;
        final sy = center.dy - y3 * w * viewScale; // Invert Y for screen space

        projectedPoints.add(Offset(sx, sy));

        // Diffuse light (Lambertian)
        final dotL = nx3 * lx + ny3 * ly + nz3 * lz;
        final diffuse = math.max(0.0, dotL);

        // Specular light (Blinn-Phong)
        const hx = lx;
        const hy = ly;
        final hz = lz + 1.0;
        final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
        final dotH = (nx3 * (hx / hLen) + ny3 * (hy / hLen) + nz3 * (hz / hLen));
        final spec = math.pow(math.max(0.0, dotH), partShininess).toDouble();

        // Total lighting multiplier
        const ambient = 0.38;
        final light = (ambient + diffuse * 0.58 + spec * 0.35).clamp(0.15, 1.45);

        // Sweet-spot highlighting on blade center
        double sweetSpotGlow = 0.0;
        if (part.name == 'blade' && y0 > -0.05 && y0 < 0.6) {
          final distSq = (x0 * x0 * 4.0) + math.pow(y0 - 0.28, 2);
          if (distSq < 0.16) {
            sweetSpotGlow = (1.0 - math.sqrt(distSq) / 0.4).clamp(0.0, 1.0) * 0.3;
          }
        }

        final motifGlow = part.name == 'blade'
            ? _motifGlow(paddle.resolvedDesign, x0, y0)
            : 0.0;
        final accent = paddle.sweetSpotColor;
        final rFinal = ((rBase * light) + (sweetSpotGlow * 255) + motifGlow * accent.r * 255)
            .clamp(0, 255)
            .round();
        final gFinal = ((gBase * light) + (sweetSpotGlow * 255) + motifGlow * accent.g * 255)
            .clamp(0, 255)
            .round();
        final bFinal = ((bBase * light) + (sweetSpotGlow * 255) + motifGlow * accent.b * 255)
            .clamp(0, 255)
            .round();

        vertexColors.add(Color.fromARGB(255, rFinal, gFinal, bFinal));
      }

      // Convert indices to Int32List required by ui.Vertices
      final indicesInt32 = Int32List(part.indexCount);
      for (int k = 0; k < part.indexCount; k++) {
        indicesInt32[k] = part.indices[k];
      }

      final uiVertices = ui.Vertices(
        ui.VertexMode.triangles,
        projectedPoints,
        colors: vertexColors,
        indices: indicesInt32,
      );

      final paintMesh = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawVertices(uiVertices, BlendMode.srcOver, paintMesh);
    }
  }

  (double, double) _profileScale(PaddleDesign design) => switch (design) {
        PaddleDesign.lightning => (0.90, 1.10),
        PaddleDesign.inferno => (1.12, 1.02),
        PaddleDesign.sovereign => (0.86, 1.12),
        PaddleDesign.cosmos => (1.10, 0.96),
        PaddleDesign.industrial => (1.16, 0.90),
        PaddleDesign.phantom => (0.84, 1.14),
        PaddleDesign.tournament => (1.0, 1.0),
      };

  double _motifGlow(PaddleDesign design, double x, double y) {
    final normalizedX = x.abs();
    return switch (design) {
      PaddleDesign.tournament => normalizedX < 0.035 || y.abs() < 0.035 ? 0.25 : 0.0,
      PaddleDesign.lightning => (x - math.sin(y * 12) * 0.10).abs() < 0.045 ? 0.42 : 0.0,
      PaddleDesign.inferno => (normalizedX - (0.10 + y.abs() * 0.10)).abs() < 0.045 ? 0.34 : 0.0,
      PaddleDesign.sovereign => (y > 0.10 && (normalizedX - 0.16).abs() < 0.045) ? 0.40 : 0.0,
      PaddleDesign.cosmos => (math.sqrt(x * x + y * y) - 0.24).abs() < 0.045 ? 0.38 : 0.0,
      PaddleDesign.industrial => (normalizedX > 0.20 || (y * 8).round().isEven) ? 0.18 : 0.0,
      PaddleDesign.phantom => (x + y * 0.32).abs() < 0.05 ? 0.34 : 0.0,
    };
  }

  @override
  bool shouldRepaint(covariant Racket3DPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.zoom != zoom ||
        oldDelegate.paddle.id != paddle.id;
  }
}
