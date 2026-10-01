import 'package:flutter/material.dart';
import '../main.dart' show PickleballGame; // To navigate to the game
import '../game_simulation.dart' show BotDifficulty;
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../widgets/background_painter.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _showDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'SELECT CPU DIFFICULTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildDifficultyOption(
                context: context,
                dialogContext: ctx,
                difficulty: BotDifficulty.easy,
                icon: Icons.sentiment_satisfied,
                title: 'Easy',
                subtitle: 'Slower reactions and more mistakes',
              ),
              const Divider(color: Colors.white12, height: 1),
              _buildDifficultyOption(
                context: context,
                dialogContext: ctx,
                difficulty: BotDifficulty.normal,
                icon: Icons.sports_tennis,
                title: 'Normal',
                subtitle: 'Balanced reactions and accuracy',
              ),
              const Divider(color: Colors.white12, height: 1),
              _buildDifficultyOption(
                context: context,
                dialogContext: ctx,
                difficulty: BotDifficulty.hard,
                icon: Icons.local_fire_department,
                title: 'Hard',
                subtitle: 'Fast, accurate, and aggressive',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyOption({
    required BuildContext context,
    required BuildContext dialogContext,
    required BotDifficulty difficulty,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _buildModeOption(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () {
        Navigator.pop(dialogContext);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PickleballGame(botDifficulty: difficulty),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background layer
          const AnimatedBackground(),
          
          // SafeArea for UI elements
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Profile
                      _buildProfilePill(context),
                      // Right: Currencies & Settings
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCurrencyPill(),
                          const SizedBox(width: 12),
                          _buildIconButton(Icons.settings, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          }),
                        ],
                      ),
                    ],
                  ),

                  Positioned(
                    left: 32,
                    top: 100,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.panel(
                          accent: AppTheme.accentLime,
                          radius: AppTheme.radiusLarge,
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PICKLEBALL',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 42,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.5,
                              ),
                            ),
                            Text(
                              'MASTERS',
                              style: TextStyle(
                                color: AppTheme.accentLime,
                                fontSize: 42,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'READ THE BOUNCE. OWN THE KITCHEN.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom Right: Start Match Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: _buildStartMatchButton(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePill(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        // Avatar
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.accentLime, AppTheme.accentTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.sports_tennis, color: AppTheme.ink, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        // Name & Level
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Guest00012',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'LV 01',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }

  Widget _buildCurrencyPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          const Text(
            '340',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.panelBg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: AppTheme.accentLime, size: 22),
      ),
    );
  }

  Widget _buildStartMatchButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: const Text(
                        'SELECT GAME MODE',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildModeOption(
                      icon: Icons.person,
                      title: 'Player vs Bot',
                      subtitle: 'Classic gameplay',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showDifficultyDialog(context);
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _buildModeOption(
                      icon: Icons.smart_display,
                      title: 'Spectate',
                      subtitle: 'Bot vs Bot',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PickleballGame(gameMode: 1)),
                        );
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _buildModeOption(
                      icon: Icons.directions_run,
                      title: 'Practice Facility',
                      subtitle: 'Free Roam & Ball Machine',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PickleballGame(gameMode: 2)),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          }
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentLime, AppTheme.accentGold],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentLime.withValues(alpha: 0.35),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'START A MATCH',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFF59E0B), size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

