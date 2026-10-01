import 'package:flutter/material.dart';

import '../settings_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/game_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settings = SettingsManager();

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Settings',
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, child) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24.0),
                children: [
                  Container(
                    decoration: AppTheme.glassPanel,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.gamepad,
                              color: AppTheme.accentCyan,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'CONTROLS CUSTOMIZATION',
                              style: AppTheme.titleStyle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Opacity Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Button Opacity',
                              style: AppTheme.bodyStyle,
                            ),
                            Text(
                              '${(_settings.buttonOpacity * 100).toInt()}%',
                              style: AppTheme.subtitleStyle,
                            ),
                          ],
                        ),
                        Slider(
                          value: _settings.buttonOpacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: AppTheme.accentCyan,
                          inactiveColor: AppTheme.borderSubtle,
                          onChanged: (val) => _settings.setButtonOpacity(val),
                        ),
                        const SizedBox(height: 24),

                        // Scale Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Button Size',
                              style: AppTheme.bodyStyle,
                            ),
                            Text(
                              '${_settings.buttonScale.toStringAsFixed(1)}x',
                              style: AppTheme.subtitleStyle,
                            ),
                          ],
                        ),
                        Slider(
                          value: _settings.buttonScale,
                          min: 0.5,
                          max: 1.5,
                          activeColor: AppTheme.accentCyan,
                          inactiveColor: AppTheme.borderSubtle,
                          onChanged: (val) => _settings.setButtonScale(val),
                        ),
                        const SizedBox(height: 16),

                        // Left-Handed Mode
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Left-Handed Mode',
                            style: AppTheme.bodyStyle,
                          ),
                          subtitle: const Text(
                            'Swaps the Joystick and Action buttons',
                            style: AppTheme.subtitleStyle,
                          ),
                          value: _settings.isLeftHanded,
                          activeTrackColor: AppTheme.accentCyan,
                          inactiveTrackColor: AppTheme.borderSubtle,
                          onChanged: (val) => _settings.setIsLeftHanded(val),
                        ),
                        const Divider(height: 32),
                        const Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              color: AppTheme.accentLime,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'VISUAL ACCESSIBILITY',
                              style: AppTheme.titleStyle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Reduced Motion',
                            style: AppTheme.bodyStyle,
                          ),
                          subtitle: const Text(
                            'Limits camera shake and animated effects',
                            style: AppTheme.subtitleStyle,
                          ),
                          value: _settings.reducedMotion,
                          activeTrackColor: AppTheme.accentCyan,
                          onChanged: _settings.setReducedMotion,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'High-Contrast Ball',
                            style: AppTheme.bodyStyle,
                          ),
                          subtitle: const Text(
                            'Adds a stronger outline for ball tracking',
                            style: AppTheme.subtitleStyle,
                          ),
                          value: _settings.highContrast,
                          activeTrackColor: AppTheme.accentCyan,
                          onChanged: _settings.setHighContrast,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Gameplay Effects',
                            style: AppTheme.bodyStyle,
                          ),
                          subtitle: const Text(
                            'Trails, bounce rings, impact bursts, and dash effects',
                            style: AppTheme.subtitleStyle,
                          ),
                          value: _settings.showEffects,
                          activeTrackColor: AppTheme.accentCyan,
                          onChanged: _settings.setShowEffects,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Impact Haptics',
                            style: AppTheme.bodyStyle,
                          ),
                          subtitle: const Text(
                            'Adds tactile feedback to successful hits',
                            style: AppTheme.subtitleStyle,
                          ),
                          value: _settings.hapticsEnabled,
                          activeTrackColor: AppTheme.accentCyan,
                          onChanged: _settings.setHapticsEnabled,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
