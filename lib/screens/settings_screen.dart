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
                            Icon(Icons.gamepad, color: AppTheme.accentCyan, size: 28),
                            SizedBox(width: 12),
                            Text('CONTROLS CUSTOMIZATION', style: AppTheme.titleStyle),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // Opacity Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Button Opacity', style: AppTheme.bodyStyle),
                            Text('${(_settings.buttonOpacity * 100).toInt()}%', style: AppTheme.subtitleStyle),
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
                            const Text('Button Size', style: AppTheme.bodyStyle),
                            Text('${_settings.buttonScale.toStringAsFixed(1)}x', style: AppTheme.subtitleStyle),
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
                          title: const Text('Left-Handed Mode', style: AppTheme.bodyStyle),
                          subtitle: const Text('Swaps the Joystick and Action buttons', style: AppTheme.subtitleStyle),
                          value: _settings.isLeftHanded,
                          activeTrackColor: AppTheme.accentCyan,
                          inactiveTrackColor: AppTheme.borderSubtle,
                          onChanged: (val) => _settings.setIsLeftHanded(val),
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

