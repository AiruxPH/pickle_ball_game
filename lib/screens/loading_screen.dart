import 'package:flutter/material.dart';
import 'main_menu_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/background_painter.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();

    // Animated loading dots
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _dotCount = (_dotCount % 3) + 1);
          _dotController.reset();
          _dotController.forward();
        }
      });
    _dotController.forward();

    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Show loading screen long enough to see the 3D model
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background layer
          const AnimatedBackground(),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 3D spinning pickleball ─────────────────────────────
              AnimatedBuilder(
                animation: _dotController,
                builder: (context, child) => Transform.rotate(
                  angle: _dotController.value * 0.7,
                  child: child,
                ),
                child: const _PickleballBrandMark(),
              ),

              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────
              Text(
                'PICKLEBALL MASTERS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                      color: AppTheme.accentLime,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                      blurRadius: 20,
                    ),
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Loading indicator ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'LOADING$dots',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickleballBrandMark extends StatelessWidget {
  const _PickleballBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFF4FFB0), AppTheme.accentLime, Color(0xFF849B20)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFFF8FFD8), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentLime.withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: 7,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Stack(
        children: [
          _BallHole(left: 38, top: 30, size: 17),
          _BallHole(right: 33, top: 47, size: 14),
          _BallHole(left: 53, bottom: 30, size: 14),
          _BallHole(right: 48, bottom: 42, size: 12),
          _BallHole(left: 77, top: 72, size: 13),
        ],
      ),
    );
  }
}

class _BallHole extends StatelessWidget {
  const _BallHole({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF657715),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x88748718)),
        ),
      ),
    );
  }
}
