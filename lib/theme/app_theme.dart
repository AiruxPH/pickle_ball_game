import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bgDark = Color(0xFF0B132B);
  static const Color surfaceDark = Color(0xFF1A1F24);
  static const Color accentCyan = Colors.cyanAccent;
  static const Color accentTeal = Colors.teal;
  static const Color accentLime = Color(0xFFD4E157);
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  
  static const Color borderSubtle = Colors.white12;
  static const Color panelBg = Color(0xCC1A1F24); // 80% opacity for glass effect

  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    color: accentCyan,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );

  static const TextStyle titleStyle = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Decorations
  static BoxDecoration get glassPanel => BoxDecoration(
    color: panelBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderSubtle, width: 1.5),
  );

  static BoxDecoration get glowButton => BoxDecoration(
    color: Colors.black87,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: accentCyan.withValues(alpha: 0.5), width: 2),
    boxShadow: [
      BoxShadow(
        color: accentCyan.withValues(alpha: 0.4),
        blurRadius: 15,
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration get iconButton => BoxDecoration(
    color: panelBg,
    shape: BoxShape.circle,
    border: Border.all(color: borderSubtle),
  );
}

