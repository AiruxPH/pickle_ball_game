import '../game_simulation.dart';

/// The progression phase of the two-tap serve rhythm mechanic.
enum ServeRhythmPhase {
  /// Player is standing ready to serve; trajectory guide is visible.
  idle,

  /// Ball has been tossed in the air; the timing cursor is active.
  tossing,

  /// Ball was struck successfully.
  complete,

  /// Ball was missed or dropped; player gets a penalty-free re-serve.
  whiffed,
}

/// The evaluated outcome of a player's strike timing during a serve.
class ServeTimingResult {
  final ShotQuality quality;
  final double powerMultiplier;
  final String feedbackMessage;
  final bool isWhiff;

  const ServeTimingResult({
    required this.quality,
    required this.powerMultiplier,
    required this.feedbackMessage,
    required this.isWhiff,
  });

  static const whiff = ServeTimingResult(
    quality: ShotQuality.early,
    powerMultiplier: 0.0,
    feedbackMessage: 'DO OVER!',
    isWhiff: true,
  );
}
