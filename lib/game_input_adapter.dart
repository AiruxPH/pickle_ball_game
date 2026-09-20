import 'dart:math' as math;
import 'package:flutter/gestures.dart';

/// Handles joystick input state and normalization.
///
/// Uses pointer-ID tracking and a relative anchor so the knob always
/// starts exactly where the finger lands.
class GameInputAdapter {
  static const double _knobRadius = 45.0;

  double joystickX = 0.0;
  double joystickY = 0.0;

  /// Called whenever joystick values change, including a reset to (0, 0).
  void Function(double x, double y)? onJoystickChanged;

  int? _activePointerId;
  Offset? _anchorPosition; // where the finger first touched

  /// Call this from onPointerDown to anchor the joystick.
  void onPointerDown(PointerDownEvent event) {
    if (_activePointerId != null) return; // ignore multi-touch extras
    _activePointerId = event.pointer;
    _anchorPosition = event.localPosition;
  }

  /// Call this from onPointerMove.
  void onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId) return;
    final anchor = _anchorPosition;
    if (anchor == null) return;
    double dx = event.localPosition.dx - anchor.dx;
    double dy = event.localPosition.dy - anchor.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > _knobRadius) {
      dx = (dx / distance) * _knobRadius;
      dy = (dy / distance) * _knobRadius;
    }
    joystickX = dx / _knobRadius;
    joystickY = dy / _knobRadius;
    onJoystickChanged?.call(joystickX, joystickY);
  }

  /// Call this from onPointerUp or onPointerCancel.
  void onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    _release();
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _release();
  }

  void _release() {
    _activePointerId = null;
    _anchorPosition = null;
    joystickX = 0.0;
    joystickY = 0.0;
    onJoystickChanged?.call(0.0, 0.0);
  }

  /// Reset forcefully (e.g. when the game pauses).
  void resetJoystick() {
    _activePointerId = null;
    _anchorPosition = null;
    joystickX = 0.0;
    joystickY = 0.0;
    onJoystickChanged?.call(0.0, 0.0);
  }

  /// Visual knob offset in logical pixels (capped to _knobRadius).
  Offset get knobOffset => Offset(joystickX * _knobRadius, joystickY * _knobRadius);
}