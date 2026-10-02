import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'settings_manager.dart';
import 'theme/app_theme.dart';

// Re-export the game screen for backward compatibility.
export 'screens/game_screen.dart' show PickleballGame;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsManager().init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Use the full landscape display on mobile. SafeArea still keeps interactive
  // UI clear of notches, camera cutouts, and rounded corners.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoadingScreen(),
    ),
  );
}
