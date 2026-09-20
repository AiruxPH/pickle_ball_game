import 'package:flutter/material.dart';
import 'main_menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadImagesAndNavigate();
  }

  Future<void> _loadImagesAndNavigate() async {
    // Wait for context to be fully available
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    try {
      // Precache the menu background image
      await precacheImage(
        ResizeImage(const AssetImage('assets/menu_bg.jpg'), width: 1200),
        context,
      );
    } catch (e) {
      debugPrint('Failed to precache menu_bg.jpg: $e');
    }

    // Give it a brief moment so the loading screen is visible
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/loading_bg.jpg',
            fit: BoxFit.cover,
            cacheWidth: 1200,
          ),
          // Dark overlay to make text pop
          Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
          // Text Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'PICKLEBALL MASTERS',
                style: TextStyle(
                  fontSize: 54,
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
              const SizedBox(height: 16),
              const Text(
                'LOADING...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

