import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Handles joystick input state and normalization.
///
/// Call [updateJoystick] with the raw pan-gesture local position and
/// [resetJoystick] when the gesture ends. Subscribe to [onJoystickChanged]
/// to receive normalised (-1..1) x/y values whenever input changes.
class GameInputAdapter {
  static const double _joystickRadius = 70.0;
  static const double _knobRadius = 45.0;

  double joystickX = 0.0;
  double joystickY = 0.0;

  /// Called whenever joystick values change, including a reset to (0, 0).
  void Function(double x, double y)? onJoystickChanged;

  /// Updates the joystick from a raw pan-gesture [localPosition].
  void updateJoystick(Offset localPosition) {
    double dx = localPosition.dx - _joystickRadius;
    double dy = localPosition.dy - _joystickRadius;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > _knobRadius) {
      dx = (dx / distance) * _knobRadius;
      dy = (dy / distance) * _knobRadius;
    }
    joystickX = dx / _knobRadius;
    joystickY = dy / _knobRadius;
    onJoystickChanged?.call(joystickX, joystickY);
  }

  /// Resets the joystick to the centre position.
  void resetJoystick() {
    joystickX = 0.0;
    joystickY = 0.0;
    onJoystickChanged?.call(0.0, 0.0);
  }
}