import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme/app_theme.dart';
import '../widgets/angular_frame.dart';
import '../widgets/game_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Which 3D model is currently shown in the viewer.
  int _selectedModelIndex = 0;

  static const List<_ModelEntry> _models = [
    _ModelEntry(
      label: 'Court',
      path: 'assets/models/pickleball-court.glb',
      icon: Icons.sports_tennis,
    ),
    _ModelEntry(
      label: 'Racket',
      path: 'assets/models/racket_for_pickleball.glb',
      icon: Icons.sports_handball,
    ),
    _ModelEntry(
      label: 'Bleachers',
      path: 'assets/models/sports_bleachers.glb',
      icon: Icons.stadium,
    ),
    _ModelEntry(
      label: 'Arena',
      path: 'assets/models/low_poly_stadiumsports_arena_seats.glb',
      icon: Icons.account_balance,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    return GameScaffold(
      title: 'Player Profile',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24.0),
            children: [
              // ── Header card ──────────────────────────────────────────
              AngularFrame(
                accent: AppTheme.accentCyan,
                cut: 16,
                padding: EdgeInsets.all(compact ? 16 : 24),
                fillColors: const [AppTheme.surfaceRaised, AppTheme.panelBg],
                child: Row(
                  children: [
                    Container(
                      width: compact ? 60 : 80,
                      height: compact ? 60 : 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.accentCyan, AppTheme.accentTeal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: compact ? 36 : 48,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: compact ? 16 : 24),
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

              SizedBox(height: compact ? 14 : 24),

              // ── Stats row ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('MATCHES', '0', Icons.sports_tennis),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('WINS', '0', Icons.emoji_events),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('LONGEST RALLY', '0', Icons.timeline),
                  ),
                ],
              ),

              SizedBox(height: compact ? 14 : 24),

              // ── 3D Equipment Viewer ───────────────────────────────────
              AngularFrame(
                accent: AppTheme.accentCyan,
                cut: 16,
                padding: EdgeInsets.all(compact ? 14 : 20),
                fillColors: const [AppTheme.surfaceRaised, AppTheme.panelBg],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EQUIPMENT SHOWCASE',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 12),

                    // Model selector tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_models.length, (i) {
                          final selected = i == _selectedModelIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedModelIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.accentCyan.withValues(
                                          alpha: 0.25,
                                        )
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.accentCyan
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _models[i].icon,
                                      size: 16,
                                      color: selected
                                          ? AppTheme.accentCyan
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _models[i].label,
                                      style: TextStyle(
                                        color: selected
                                            ? AppTheme.accentCyan
                                            : Colors.white54,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3D model viewer
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: compact ? 210 : 300,
                        child: ModelViewer(
                          key: ValueKey(_selectedModelIndex),
                          src: _models[_selectedModelIndex].path,
                          alt: _models[_selectedModelIndex].label,
                          autoRotate: true,
                          cameraControls: true,
                          backgroundColor: const Color(0xFF0B1A2E),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Drag to rotate • Pinch to zoom',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return AngularFrame(
      accent: AppTheme.accentCyan,
      cut: 12,
      padding: const EdgeInsets.all(16),
      fillColors: const [AppTheme.surfaceRaised, AppTheme.panelBg],
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentCyan, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.titleStyle.copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

class _ModelEntry {
  final String label;
  final String path;
  final IconData icon;

  const _ModelEntry({
    required this.label,
    required this.path,
    required this.icon,
  });
}
