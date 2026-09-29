import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'main_menu_screen.dart';
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
              SizedBox(
                width: 220,
                height: 220,
                child: ClipOval(
                  child: ModelViewer(
                    src: 'assets/models/pickleball.glb',
                    alt: 'A 3D pickleball',
                    autoRotate: true,
                    cameraControls: false,
                    backgroundColor: Colors.transparent,
                    autoPlay: true,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────
              Text(
                'PICKLEBALL MASTERS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD4E157),
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
                          AlwaysStoppedAnimation<Color>(Color(0xFF18FFFF)),
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
