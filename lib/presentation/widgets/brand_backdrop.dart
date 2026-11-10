import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Forkcast's signature atmosphere: a soft, static matcha-and-peach glow at
/// the top of the canvas. Static on purpose (no full-screen motion).
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = BrandSurfaces.aurora(context.isDark);
    final width = MediaQuery.sizeOf(context).width;

    Widget glow(Color c, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)], stops: const [0, 1]),
        ),
      ),
    );

    return ColoredBox(
      color: context.theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(left: -width * 0.35, top: -width * 0.45, child: glow(colors[0], width * 1.1)),
          Positioned(right: -width * 0.4, top: -width * 0.25, child: glow(colors[1], width * 0.95)),
          Positioned(left: width * 0.15, top: width * 0.55, child: glow(colors[2], width * 0.8)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
