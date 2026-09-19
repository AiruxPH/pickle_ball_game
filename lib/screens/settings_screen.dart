import 'package:flutter/material.dart';
import '../settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settings = SettingsManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.black87),
      backgroundColor: const Color(0xFF1A1F24),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const Text('Controls Customization', style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // Opacity Slider
              Text('Button Opacity: ${(_settings.buttonOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
              Slider(
                value: _settings.buttonOpacity,
                min: 0.1,
                max: 1.0,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => _settings.setButtonOpacity(val),
              ),
              const SizedBox(height: 16),
              
              // Scale Slider
              Text('Button Size: ${_settings.buttonScale.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white)),
              Slider(
                value: _settings.buttonScale,
                min: 0.5,
                max: 1.5,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => _settings.setButtonScale(val),
              ),
              const SizedBox(height: 16),
              
              // Left-Handed Mode
              SwitchListTile(
                title: const Text('Left-Handed Mode', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Swaps the Joystick and Action buttons', style: TextStyle(color: Colors.white70)),
                value: _settings.isLeftHanded,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => _settings.setIsLeftHanded(val),
              ),
            ],
          );
        },
      ),
    );
  }
}

