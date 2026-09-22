import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'background_painter.dart';

class GameScaffold extends StatelessWidget {
  final Widget child;
  final String title;
  final bool showBackButton;

  const GameScaffold({
    super.key,
    required this.child,
    this.title = '',
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background layer
          const Positioned.fill(child: AnimatedBackground()),
          
          // Foreground layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom HUD Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      if (showBackButton)
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: AppTheme.iconButton,
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppTheme.accentCyan,
                              size: 24,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 44, height: 44), // Placeholder to keep title centered
                      
                      Expanded(
                        child: Center(
                          child: Text(
                            title.toUpperCase(),
                            style: AppTheme.headingStyle,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 44, height: 44), // Right placeholder
                    ],
                  ),
                ),
                
                // Body Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

