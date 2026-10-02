import 'package:flutter/material.dart';

import '../game_input_adapter.dart';

/// On-screen circular virtual joystick for player directional movement.
class VirtualJoystickWidget extends StatelessWidget {
  final GameInputAdapter input;
  final double scale;
  final VoidCallback onInputUpdate;

  const VirtualJoystickWidget({
    super.key,
    required this.input,
    required this.scale,
    required this.onInputUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Move player',
      child: Listener(
        onPointerDown: (e) {
          input.onPointerDown(e);
          onInputUpdate();
        },
        onPointerMove: (e) {
          input.onPointerMove(e);
          onInputUpdate();
        },
        onPointerUp: (e) {
          input.onPointerUp(e);
          onInputUpdate();
        },
        onPointerCancel: (e) {
          input.onPointerCancel(e);
          onInputUpdate();
        },
        child: Container(
          width: 140 * scale,
          height: 140 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Transform.translate(
              offset: input.knobOffset * scale,
              child: Container(
                width: 50 * scale,
                height: 50 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large interactive action button for serving or hitting the ball.
class HitButtonWidget extends StatelessWidget {
  final bool isServing;
  final double scale;
  final VoidCallback onTap;

  const HitButtonWidget({
    super.key,
    required this.isServing,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = isServing ? 'SERVE' : 'HIT';
    final buttonColor =
        isServing ? const Color(0xFFFF6D00) : const Color(0xFFF59E0B);
    final textColor = isServing ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      label: isServing ? 'Serve the ball' : 'Hit the ball',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90 * scale,
          height: 90 * scale,
          decoration: BoxDecoration(
            color: buttonColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
          child: Center(
            child: Text(
              buttonText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22 * scale,
                color: textColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular lightning action button to trigger a dash burst.
class DashButtonWidget extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const DashButtonWidget({
    super.key,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dash',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60 * scale,
          height: 60 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFB923C).withValues(alpha: 0.6),
              width: 2.0,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.bolt,
              color: const Color(0xFFFB923C),
              size: 36 * scale,
            ),
          ),
        ),
      ),
    );
  }
}

/// Camera mode switch button.
class CameraButtonWidget extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const CameraButtonWidget({
    super.key,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70 * scale,
        height: 70 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F24).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
            width: 2.0,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.videocam,
            color: const Color(0xFFF59E0B),
            size: 36 * scale,
          ),
        ),
      ),
    );
  }
}

/// Rotated vertical altitude adjustment slider for free-roam camera mode.
class AltitudeSliderWidget extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const AltitudeSliderWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3, // Vertical slider
      child: Container(
        width: 150,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F24).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
          ),
        ),
        child: Slider(
          min: 0.4,
          max: 2.8,
          activeColor: const Color(0xFFF59E0B),
          inactiveColor: Colors.white12,
          value: value.clamp(0.4, 2.8),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
