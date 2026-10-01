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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 500;
    final edgePadding = compact ? 12.0 : 24.0;
    final headerHeight = compact ? 36.0 : 44.0;

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
                  padding: EdgeInsets.symmetric(
                    horizontal: edgePadding,
                    vertical: compact ? 6 : 16,
                  ),
                  child: Row(
                    children: [
                      if (showBackButton)
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: headerHeight,
                            height: headerHeight,
                            decoration: AppTheme.iconButton,
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppTheme.accentCyan,
                              size: compact ? 20 : 24,
                            ),
                          ),
                        )
                      else
                        SizedBox(width: headerHeight, height: headerHeight),

                      Expanded(
                        child: Center(
                          child: Text(
                            title.toUpperCase(),
                            style: AppTheme.headingStyle.copyWith(
                              fontSize: compact ? 17 : 20,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: headerHeight, height: headerHeight),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 32,
                    ),
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
