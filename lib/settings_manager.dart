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
  bool _reducedMotion = false;
  bool _highContrast = false;
  bool _showEffects = true;
  bool _hapticsEnabled = true;
  String _equippedPaddleId = 'pro_tournament';

  double get buttonOpacity => _buttonOpacity;
  double get buttonScale => _buttonScale;
  bool get isLeftHanded => _isLeftHanded;
  bool get reducedMotion => _reducedMotion;
  bool get highContrast => _highContrast;
  bool get showEffects => _showEffects;
  bool get hapticsEnabled => _hapticsEnabled;
  String get equippedPaddleId => _equippedPaddleId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _buttonOpacity = _prefs?.getDouble('buttonOpacity') ?? 1.0;
    _buttonScale = _prefs?.getDouble('buttonScale') ?? 1.0;
    _isLeftHanded = _prefs?.getBool('isLeftHanded') ?? false;
    _reducedMotion = _prefs?.getBool('reducedMotion') ?? false;
    _highContrast = _prefs?.getBool('highContrast') ?? false;
    _showEffects = _prefs?.getBool('showEffects') ?? true;
    _hapticsEnabled = _prefs?.getBool('hapticsEnabled') ?? true;
    _equippedPaddleId =
        _prefs?.getString('equippedPaddleId') ?? 'pro_tournament';
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

  Future<void> setReducedMotion(bool value) async {
    _reducedMotion = value;
    await _prefs?.setBool('reducedMotion', value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await _prefs?.setBool('highContrast', value);
    notifyListeners();
  }

  Future<void> setShowEffects(bool value) async {
    _showEffects = value;
    await _prefs?.setBool('showEffects', value);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    await _prefs?.setBool('hapticsEnabled', value);
    notifyListeners();
  }

  Future<void> setEquippedPaddleId(String value) async {
    _equippedPaddleId = value;
    await _prefs?.setString('equippedPaddleId', value);
    notifyListeners();
  }
}
