import 'package:flutter/material.dart';

import '../models/paddle_item.dart';
import 'angular_frame.dart';

/// Card item rendered within the Paddle Shop horizontal carousel.
class PaddleCarouselCard extends StatelessWidget {
  final PaddleItem paddle;
  final bool isSelected;
  final bool isEquipped;
  final VoidCallback onTap;

  const PaddleCarouselCard({
    super.key,
    required this.paddle,
    required this.isSelected,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? paddle.energyColor : Colors.white24;
    final scale = isSelected ? 1.0 : 0.92;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AngularFrame(
          accent: borderColor,
          cut: 14,
          fillColors: isSelected
              ? [
                  const Color(0xFF1E293B),
                  paddle.energyColor.withValues(alpha: 0.15),
                ]
              : [
                  const Color(0xFF0F172A),
                  const Color(0xFF090E17),
                ],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        constraints.maxWidth > 0 ? constraints.maxWidth : 180,
                    minHeight:
                        constraints.maxHeight > 0 ? constraints.maxHeight : 84,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
              // Top Row: Rarity badge & Equipped tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: paddle.rarityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: paddle.rarityColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      paddle.rarityLabel,
                      style: TextStyle(
                        color: paddle.rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (isEquipped)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 10, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'EQUIPPED',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Middle: Name & Tagline
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    paddle.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paddle.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: paddle.energyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // Bottom Row: Swatches & Select indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Palette circles
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSwatch(paddle.paddleFaceColor),
                      const SizedBox(width: 4),
                      _buildSwatch(paddle.paddleRimColor),
                      const SizedBox(width: 4),
                      _buildSwatch(paddle.energyColor),
                    ],
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? paddle.energyColor : Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ),
),
),
);
}

  Widget _buildSwatch(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 1),
      ),
    );
  }
}
