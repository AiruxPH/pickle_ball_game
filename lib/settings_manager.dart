import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  SharedPreferences? _prefs;

  // Defaults
  double _buttonOpacity = 1.0;
  double _buttonScale = 1.0;
  bool _isLeftHanded = false;

  double get buttonOpacity => _buttonOpacity;
  double get buttonScale => _buttonScale;
  bool get isLeftHanded => _isLeftHanded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _buttonOpacity = _prefs?.getDouble('buttonOpacity') ?? 1.0;
    _buttonScale = _prefs?.getDouble('buttonScale') ?? 1.0;
    _isLeftHanded = _prefs?.getBool('isLeftHanded') ?? false;
    notifyListeners();
  }

  Future<void> setButtonOpacity(double value) async {
    _buttonOpacity = value;
    await _prefs?.setDouble('buttonOpacity', value);
    notifyListeners();
  }

  Future<void> setButtonScale(double value) async {
    _buttonScale = value;
    await _prefs?.setDouble('buttonScale', value);
    notifyListeners();
  }

  Future<void> setIsLeftHanded(bool value) async {
    _isLeftHanded = value;
    await _prefs?.setBool('isLeftHanded', value);
    notifyListeners();
  }
}

