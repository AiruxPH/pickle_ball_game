import 'package:flutter/material.dart';

import 'court_diagram_painter.dart';

/// Interactive 2D court diagram widget with regulation pickleball annotations.
class CourtDiagramWidget extends StatefulWidget {
  final double height;

  const CourtDiagramWidget({super.key, this.height = 160});

  @override
  State<CourtDiagramWidget> createState() => _CourtDiagramWidgetState();
}

class _CourtDiagramWidgetState extends State<CourtDiagramWidget> {
  int _highlightedZone = 1; // Default to showing Kitchen

  @override
  Widget build(BuildContext context) {
    // 20 ft by 44 ft -> width to height ratio = 20 / 44 = 0.4545
    final diagramHeight = widget.height;
    final diagramWidth = diagramHeight * (20.0 / 44.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Visual Blueprint Canvas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CustomPaint(
              size: Size(diagramWidth, diagramHeight),
              painter: CourtDiagramPainter(highlightedZone: _highlightedZone),
            ),
          ),
          const SizedBox(width: 14),

          // Interactive Zone Selector & Dimensions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.architecture, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'USAP REGULATION COURT',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '20 ft (6.1m) W x 44 ft (13.4m) L',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Net: 36" posts, 34" center | NVZ: 7 ft deep',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 8),

                // Interactive Highlight Filters
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildZoneChip('Kitchen (NVZ)', 1, const Color(0xFFE11D48)),
                    _buildZoneChip('Right Service', 2, const Color(0xFF00E5FF)),
                    _buildZoneChip('Left Service', 3, const Color(0xFFF59E0B)),
                    _buildZoneChip('Baselines', 4, const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneChip(String label, int zoneIndex, Color color) {
    final isSelected = _highlightedZone == zoneIndex;
    return GestureDetector(
      onTap: () => setState(() => _highlightedZone = isSelected ? 0 : zoneIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
