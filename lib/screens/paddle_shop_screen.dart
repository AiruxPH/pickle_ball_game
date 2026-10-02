import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/paddle_item.dart';
import '../settings_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/angular_frame.dart';
import '../widgets/paddle_3d_preview.dart';
import '../widgets/paddle_carousel_card.dart';
import '../widgets/paddle_stats_panel.dart';

/// Full-featured Paddle Shop screen with an interactive 3D model inspector and
/// a horizontal snapping carousel for selecting and equipping paddles.
class PaddleShopScreen extends StatefulWidget {
  const PaddleShopScreen({super.key});

  @override
  State<PaddleShopScreen> createState() => _PaddleShopScreenState();
}

class _PaddleShopScreenState extends State<PaddleShopScreen> {
  final List<PaddleItem> _paddles = PaddleCatalog.allPaddles;
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final equippedId = SettingsManager().equippedPaddleId;
    final initialIndex = _paddles.indexWhere((p) => p.id == equippedId);
    _selectedIndex = initialIndex >= 0 ? initialIndex : 0;
    _pageController = PageController(
      initialPage: _selectedIndex,
      viewportFraction: 0.36,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPaddleSelected(int index) {
    if (index != _selectedIndex) {
      if (SettingsManager().hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      setState(() => _selectedIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  DateTime _lastWheelScroll = DateTime.fromMillisecondsSinceEpoch(0);

  void _handlePointerScroll(PointerScrollEvent event) {
    final now = DateTime.now();
    if (now.difference(_lastWheelScroll).inMilliseconds < 160) {
      return;
    }
    final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta > 0) {
      // Mouse scroll down: move list to left (reveal next paddle)
      if (_selectedIndex < _paddles.length - 1) {
        _lastWheelScroll = now;
        _onPaddleSelected(_selectedIndex + 1);
      }
    } else if (delta < 0) {
      // Mouse scroll up: move list to right (reveal previous paddle)
      if (_selectedIndex > 0) {
        _lastWheelScroll = now;
        _onPaddleSelected(_selectedIndex - 1);
      }
    }
  }

  Future<void> _equipCurrentPaddle() async {
    final current = _paddles[_selectedIndex];
    if (SettingsManager().hapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
    await SettingsManager().setEquippedPaddleId(current.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 520;
    final currentPaddle = _paddles[_selectedIndex];
    final isEquipped =
        SettingsManager().equippedPaddleId == currentPaddle.id;

    return Scaffold(
      backgroundColor: const Color(0xFF090E17),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 8 : 12,
          ),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'BACK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PADDLE ARSENAL',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: compact ? 16 : 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        'SELECT YOUR KINETIC BLADE',
                        style: TextStyle(
                          color: currentPaddle.energyColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  // Equip Action Button
                  GestureDetector(
                    onTap: isEquipped ? null : _equipCurrentPaddle,
                    child: AngularFrame(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      accent: isEquipped
                          ? const Color(0xFF10B981)
                          : currentPaddle.energyColor,
                      cut: 10,
                      fillColors: isEquipped
                          ? [
                              const Color(0xFF10B981),
                              const Color(0xFF059669),
                            ]
                          : [
                              currentPaddle.energyColor,
                              currentPaddle.paddleFaceColor,
                            ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEquipped ? Icons.check : Icons.sports_tennis,
                            color: Colors.black,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEquipped ? 'EQUIPPED' : 'EQUIP PADDLE',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Upper Deck: 3D Preview (Left) & Stats Specification (Right)
              Expanded(
                flex: compact ? 5 : 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 3D Model / Familiar Inspector
                    Expanded(
                      flex: 5,
                      child: Paddle3DPreview(
                        paddle: currentPaddle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Attributes & Specs
                    Expanded(
                      flex: 4,
                      child: PaddleStatsPanel(paddle: currentPaddle),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Lower Deck: Horizontal Carousel of Paddles
              SizedBox(
                height: compact ? 95 : 120,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      _handlePointerScroll(pointerSignal);
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _paddles.length,
                          onPageChanged: (idx) {
                            setState(() => _selectedIndex = idx);
                          },
                          itemBuilder: (context, index) {
                            final paddle = _paddles[index];
                            final isSelected = index == _selectedIndex;
                            final equipped =
                                SettingsManager().equippedPaddleId == paddle.id;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: PaddleCarouselCard(
                                paddle: paddle,
                                isSelected: isSelected,
                                isEquipped: equipped,
                                onTap: () => _onPaddleSelected(index),
                              ),
                            );
                          },
                        ),
                      ),

                      // Left Navigation Arrow
                      if (_selectedIndex > 0)
                        Positioned(
                          left: 0,
                          child: _buildArrowButton(
                            icon: Icons.chevron_left,
                            onTap: () => _onPaddleSelected(_selectedIndex - 1),
                          ),
                        ),

                      // Right Navigation Arrow
                      if (_selectedIndex < _paddles.length - 1)
                        Positioned(
                          right: 0,
                          child: _buildArrowButton(
                            icon: Icons.chevron_right,
                            onTap: () => _onPaddleSelected(_selectedIndex + 1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
