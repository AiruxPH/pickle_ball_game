import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/game_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Player Profile',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24.0),
            children: [
              // Header profile card
              Container(
                decoration: AppTheme.glassPanel,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.accentCyan, AppTheme.accentTeal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.person, size: 48, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    // Name and Level
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GUEST_PLAYER', style: AppTheme.headingStyle),
                          SizedBox(height: 8),
                          Text('LEVEL 01', style: AppTheme.subtitleStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats
              Row(
                children: [
                  Expanded(child: _buildStatCard('MATCHES', '0', Icons.sports_tennis)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('WINS', '0', Icons.emoji_events)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('LONGEST RALLY', '0', Icons.timeline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      decoration: AppTheme.glassPanel,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentCyan, size: 32),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.subtitleStyle),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.titleStyle.copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}
