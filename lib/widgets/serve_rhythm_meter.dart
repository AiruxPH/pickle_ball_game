import 'package:flutter/material.dart';

import '../simulation/serve_rhythm_controller.dart';
import '../simulation/serve_rhythm_state.dart';

/// Arcade cyberpunk timing meter widget for the two-tap serve rhythm mechanic.
class ServeRhythmMeter extends StatelessWidget {
  final ServeRhythmController controller;
  final double scale;

  const ServeRhythmMeter({
    super.key,
    required this.controller,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isTossing = controller.phase == ServeRhythmPhase.tossing;
    final progress = controller.progress.clamp(0.0, 1.0);

    return Container(
      width: 240 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(
          color: isTossing ? const Color(0xFF00E5FF) : Colors.white24,
          width: 1.5,
        ),
        boxShadow: [
          if (isTossing)
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isTossing ? 'HIT SWEET SPOT!' : 'SERVE METER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isTossing
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFFF59E0B),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isTossing ? 'TIMING' : 'READY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          // Meter Bar Track
          SizedBox(
            height: 18 * scale,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background Track
                Container(
                  width: double.infinity,
                  height: 10 * scale,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(5 * scale),
                  ),
                ),
                // Good Zone (Center)
                Align(
                  alignment: Alignment(
                    (ServeRhythmController.sweetSpot - 0.5) * 2.0,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor:
                        ServeRhythmController.goodTolerance * 2.0,
                    child: Container(
                      height: 10 * scale,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4 * scale),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // Perfect Sweet Spot Zone (Exact Center)
                Align(
                  alignment: Alignment(
                    (ServeRhythmController.sweetSpot - 0.5) * 2.0,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor:
                        ServeRhythmController.perfectTolerance * 2.0,
                    child: Container(
                      height: 14 * scale,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF00E5FF).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4 * scale),
                        border: Border.all(
                          color: const Color(0xFF00E5FF),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Animated Cursor / Needle
                if (isTossing)
                  FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Align(
                      alignment: Alignment((progress - 0.5) * 2.0, 0),
                      child: Container(
                        width: 6 * scale,
                        height: 18 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3 * scale),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 3 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EARLY',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'PERFECT',
                style: TextStyle(
                  color: const Color(0xFF00E5FF),
                  fontSize: 8 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'LATE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
