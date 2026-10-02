import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF07111F);
  static const Color bgDark = Color(0xFF091827);
  static const Color surfaceDark = Color(0xFF122536);
  static const Color surfaceRaised = Color(0xFF193246);
  static const Color courtBlue = Color(0xFF147D92);
  static const Color courtTeal = Color(0xFF13A6A1);
  static const Color accentCyan = Color(0xFF55E6E1);
  static const Color accentTeal = Color(0xFF13A6A1);
  static const Color accentLime = Color(0xFFD8F06A);
  static const Color accentGold = Color(0xFFFFC857);
  static const Color teamPlayer = Color(0xFFFFB84D);
  static const Color teamCpu = Color(0xFFFF5D73);
  static const Color success = Color(0xFF67E8A5);
  static const Color danger = Color(0xFFFF5D73);

  static const Color textPrimary = Color(0xFFF7FBFF);
  static const Color textSecondary = Color(0xFFB9CBD8);
  static const Color textMuted = Color(0xFF7890A0);
  static const Color borderSubtle = Color(0x3355E6E1);
  static const Color panelBg = Color(0xE6122536);

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: accentCyan,
          secondary: accentGold,
          surface: surfaceDark,
          error: danger,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
          headlineSmall: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
          labelLarge: TextStyle(
            color: textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accentCyan,
          thumbColor: accentLime,
          inactiveTrackColor: Color(0x334F7185),
        ),
        dividerColor: const Color(0x264F7185),
      );

  static const TextStyle headingStyle = TextStyle(
    color: accentLime,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.4,
  );

  static const TextStyle titleStyle = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static BoxDecoration panel({Color? accent, double radius = radiusMedium}) {
    final edge = accent ?? accentCyan;
    return BoxDecoration(
      color: panelBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: edge.withValues(alpha: 0.25), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: edge.withValues(alpha: 0.06),
          blurRadius: 18,
        ),
      ],
    );
  }

  static BoxDecoration get glassPanel => panel();

  static BoxDecoration get glowButton => BoxDecoration(
        gradient: const LinearGradient(
          colors: [accentCyan, accentTeal],
        ),
        borderRadius: BorderRadius.circular(radiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentCyan.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      );

  static BoxDecoration get iconButton => BoxDecoration(
        color: panelBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      );
}
