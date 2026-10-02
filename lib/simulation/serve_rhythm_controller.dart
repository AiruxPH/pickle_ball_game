import 'dart:math' as math;

import '../game_simulation.dart';

/// Manages the two-tap serve rhythm mini-game mechanics:
/// Tap 1 initiates the toss into the air.
/// Tap 2 strikes the ball at the sweet spot timing marker.
/// Completely missed strikes trigger a penalty-free "DO OVER".
class ServeRhythmController {
  /// Current phase of the serve rhythm.
  ServeRhythmPhase phase = ServeRhythmPhase.idle;

  /// Progress of the toss from 0.0 to 1.0.
  double progress = 0.0;

  /// Target timing sweet spot where ideal strike contact occurs.
  static const double sweetSpot = 0.65;

  /// Tolerance for a PERFECT strike.
  static const double perfectTolerance = 0.09;

  /// Tolerance for a GOOD strike.
  static const double goodTolerance = 0.22;

  /// Total duration of the ball toss in seconds.
  static const double tossDurationSeconds = 1.05;

  /// Height offset added to the ball during toss animation.
  double get ballTossZ {
    if (phase != ServeRhythmPhase.tossing && phase != ServeRhythmPhase.whiffed) {
      return 0.0;
    }
    // Parabolic arc rising to +0.32 and dropping down.
    return 0.32 * math.sin(progress.clamp(0.0, 1.0) * math.pi);
  }

  /// Initiates the ball toss into the air.
  void startToss() {
    phase = ServeRhythmPhase.tossing;
    progress = 0.0;
  }

  /// Evaluates timing when the player strikes during the toss.
  ServeTimingResult strike() {
    if (phase != ServeRhythmPhase.tossing) {
      return ServeTimingResult.whiff;
    }

    final delta = progress - sweetSpot;
    final absDelta = delta.abs();

    if (absDelta <= perfectTolerance) {
      phase = ServeRhythmPhase.complete;
      return const ServeTimingResult(
        quality: ShotQuality.perfect,
        powerMultiplier: 1.25,
        feedbackMessage: 'PERFECT SERVE!',
        isWhiff: false,
      );
    } else if (absDelta <= goodTolerance) {
      phase = ServeRhythmPhase.complete;
      return const ServeTimingResult(
        quality: ShotQuality.good,
        powerMultiplier: 1.0,
        feedbackMessage: 'GOOD SERVE',
        isWhiff: false,
      );
    } else if (progress < 0.95) {
      phase = ServeRhythmPhase.complete;
      final isEarly = delta < 0;
      return ServeTimingResult(
        quality: ShotQuality.early,
        powerMultiplier: 0.85,
        feedbackMessage: isEarly ? 'EARLY SERVE' : 'LATE SERVE',
        isWhiff: false,
      );
    } else {
      // Whiffed entirely or dropped
      phase = ServeRhythmPhase.whiffed;
      return ServeTimingResult.whiff;
    }
  }

  /// Ticks the toss progress. Returns true if a timeout whiff occurred.
  bool update(double dtSeconds) {
    if (phase != ServeRhythmPhase.tossing) return false;

    progress += dtSeconds / tossDurationSeconds;
    if (progress >= 1.05) {
      phase = ServeRhythmPhase.whiffed;
      return true;
    }
    return false;
  }

  /// Resets back to idle for a new serve or re-serve do-over.
  void reset() {
    phase = ServeRhythmPhase.idle;
    progress = 0.0;
  }
}
