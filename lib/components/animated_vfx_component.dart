import 'dart:ui';

import 'package:flame/components.dart';

import '../models/paddle_item.dart';
import '../pickleball_flame_game.dart';

/// Flame VFX component that plays a pixel-art animated spritesheet at the impact location
/// corresponding to the player's equipped paddle.
class AnimatedVfxComponent extends Component {
  final Offset center;
  final double scale;
  final PaddleItem paddle;
  final PickleballFlameGame game;

  AnimatedVfxComponent({
    required this.center,
    required this.scale,
    required this.paddle,
    required this.game,
  });

  Image? _vfxImage;
  double _timer = 0.0;
  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    if (paddle.vfxAsset == null) return;
    try {
      _vfxImage = await game.images.load(paddle.vfxAsset!);
      _loaded = true;
    } catch (_) {
      // Fallback if image fails to load
      _loaded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    final totalDuration = paddle.vfxFrameCount * paddle.vfxStepDuration;
    if (_timer >= totalDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _vfxImage == null) return;

    final frameIndex = (_timer / paddle.vfxStepDuration).floor();
    if (frameIndex >= paddle.vfxFrameCount) return;

    final col = frameIndex % paddle.vfxColumns;
    final row = (frameIndex / paddle.vfxColumns).floor();

    final src = Rect.fromLTWH(
      col * paddle.vfxFrameWidth,
      row * paddle.vfxFrameHeight,
      paddle.vfxFrameWidth,
      paddle.vfxFrameHeight,
    );

    final renderWidth = paddle.vfxFrameWidth * scale * paddle.vfxScale;
    final renderHeight = paddle.vfxFrameHeight * scale * paddle.vfxScale;

    final dst = Rect.fromCenter(
      center: center,
      width: renderWidth,
      height: renderHeight,
    );

    final progress = (_timer / (paddle.vfxFrameCount * paddle.vfxStepDuration))
        .clamp(0.0, 1.0);
    final alpha = ((1.0 - (progress * 0.4)) * 255).round().clamp(0, 255);

    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withAlpha(alpha)
      ..filterQuality = FilterQuality.none; // Preserve crisp pixel-art styling

    canvas.drawImageRect(_vfxImage!, src, dst, paint);
  }
}
