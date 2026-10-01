import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum GamePanelStyle { crimson, moltenOrange, cyberCyan, toxicLime }

enum CompactFrameStyle { crimson, cyan, purple, amber, coral, gold }

extension on GamePanelStyle {
  String get assetPath => switch (this) {
    GamePanelStyle.crimson => 'assets/ui/frames/figma_panel_crimson.svg',
    GamePanelStyle.moltenOrange => 'assets/ui/frames/figma_panel_orange.svg',
    GamePanelStyle.cyberCyan => 'assets/ui/frames/figma_panel_cyan.svg',
    GamePanelStyle.toxicLime => 'assets/ui/frames/figma_panel_lime.svg',
  };

  Color get accent => switch (this) {
    GamePanelStyle.crimson => const Color(0xFFFF1515),
    GamePanelStyle.moltenOrange => const Color(0xFFFF7A00),
    GamePanelStyle.cyberCyan => const Color(0xFF00D9FF),
    GamePanelStyle.toxicLime => const Color(0xFF72E900),
  };
}

extension on CompactFrameStyle {
  String get assetPath => switch (this) {
    CompactFrameStyle.crimson => 'assets/ui/frames/figma_compact_crimson.svg',
    CompactFrameStyle.cyan => 'assets/ui/frames/figma_compact_cyan.svg',
    CompactFrameStyle.purple => 'assets/ui/frames/figma_compact_purple.svg',
    CompactFrameStyle.amber => 'assets/ui/frames/figma_compact_amber.svg',
    CompactFrameStyle.coral => 'assets/ui/frames/figma_compact_coral.svg',
    CompactFrameStyle.gold => 'assets/ui/frames/figma_compact_gold.svg',
  };
}

/// Exact vector-backed implementation of the large panel family from the
/// project's Figma file. Content remains live Flutter UI over the artwork.
class FigmaGamePanel extends StatelessWidget {
  const FigmaGamePanel({
    super.key,
    required this.style,
    required this.child,
    this.title,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 54, 24, 24),
    this.titlePadding = const EdgeInsets.fromLTRB(18, 8, 18, 0),
  });

  final GamePanelStyle style;
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry titlePadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: SvgPicture.asset(style.assetPath, fit: BoxFit.fill),
          ),
        ),
        Padding(padding: contentPadding, child: child),
        if (title case final title?)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: titlePadding,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.52,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 9,
          top: 9,
          child: Semantics(
            label: '${style.name} panel',
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: style.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: style.accent, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Exact compact Figma frame for icon buttons, inventory slots, and menu tiles.
class FigmaCompactFrame extends StatelessWidget {
  const FigmaCompactFrame({
    super.key,
    required this.style,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 25, 12, 12),
  });

  final CompactFrameStyle style;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 116 / 108,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: SvgPicture.asset(style.assetPath, fit: BoxFit.fill),
            ),
          ),
          Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

/// Pixel-perfect export of the Figma mesh-gradient banner. Figma's mesh fill
/// is preserved in the local image while text and controls remain live widgets.
class FigmaGradientBanner extends StatelessWidget {
  const FigmaGradientBanner({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(30, 32, 30, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 595 / 271,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/ui/frames/figma_gradient_banner.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
