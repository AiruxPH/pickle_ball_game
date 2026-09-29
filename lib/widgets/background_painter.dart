import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Abstract blob fallback painter (used when images are unavailable)
// ---------------------------------------------------------------------------
class AbstractBlobPainter extends CustomPainter {
  final double animationValue;

  AbstractBlobPainter({this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0B132B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final blobPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF18FFFF).withValues(alpha: 0.15),
          const Color(0xFF009688).withValues(alpha: 0.05),
          const Color(0xFF000000).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.3),
          radius: size.height * 0.8));

    final blobPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF009688).withValues(alpha: 0.15),
          const Color(0xFF18FFFF).withValues(alpha: 0.05),
          const Color(0xFF000000).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.8, size.height * 0.8),
          radius: size.height * 0.7));

    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.3), size.height * 0.8, blobPaint1);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.8), size.height * 0.7, blobPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Image slideshow background — cycles through assets/images/1.png–6.png
// with a smooth crossfade every 5 seconds.
// Falls back to the blob painter if any image fails to load.
// ---------------------------------------------------------------------------

/// All six background images shipped with the game.
const List<String> _backgroundImages = [
  'assets/images/1.png',
  'assets/images/2.png',
  'assets/images/3.png',
  'assets/images/4.png',
  'assets/images/5.png',
  'assets/images/6.png',
];

/// How long each slide is fully visible before crossfade begins.
const Duration _slideDuration = Duration(seconds: 5);

/// Duration of the crossfade transition between slides.
const Duration _fadeDuration = Duration(milliseconds: 1500);

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _nextIndex = 1;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _imagesAvailable = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(_slideDuration, () {
      if (!mounted) return;
      _advance();
    });
  }

  Future<void> _advance() async {
    await _fadeController.forward();
    if (!mounted) return;
    setState(() {
      _currentIndex = _nextIndex;
      _nextIndex = (_nextIndex + 1) % _backgroundImages.length;
    });
    _fadeController.reset();
    _scheduleNext();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildImageLayer(String assetPath, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          if (_imagesAvailable) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _imagesAvailable = false);
            });
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fallback to abstract blob if images fail
    if (!_imagesAvailable) {
      return CustomPaint(painter: AbstractBlobPainter(), size: Size.infinite);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base: current slide (always fully opaque)
        _buildImageLayer(_backgroundImages[_currentIndex], 1.0),

        // Overlay: next slide fading in
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) => _buildImageLayer(
              _backgroundImages[_nextIndex], _fadeAnimation.value),
        ),

        // Dark gradient overlay to keep UI readable on any photo
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC0B132B), // heavy dark at top (HUD)
                Color(0x660B132B), // lighter in middle (photo visible)
                Color(0xCC0B132B), // heavy dark at bottom (controls)
              ],
            ),
          ),
        ),
      ],
    );
  }
}
