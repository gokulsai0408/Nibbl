import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/tokens.dart';

/// Entrance animations that automatically switch off for reduced motion.
///
/// Staggered at 40ms per item and capped so a whole screen settles within
/// ~600ms. Use inside non-recycling layouts (Column) so it only plays on first
/// entry, not every time an item scrolls back into view.
extension EntranceX on Widget {
  Widget entrance(BuildContext context, {int index = 0, double slide = 0.04}) {
    final delay = Duration(milliseconds: 40 * index.clamp(0, 7));
    // Reduced motion means gentler, not zero: keep the fade, drop the movement.
    if (MediaQuery.disableAnimationsOf(context)) {
      return animate(delay: delay).fadeIn(duration: 150.ms);
    }
    return animate(delay: delay)
        .fadeIn(duration: 260.ms, curve: AppCurves.easeOut)
        .slideY(begin: slide, end: 0, duration: 300.ms, curve: AppCurves.easeOut);
  }

  Widget popIn(BuildContext context, {Duration delay = Duration.zero}) {
    if (MediaQuery.disableAnimationsOf(context)) return this;
    return animate(
      delay: delay,
    ).fadeIn(duration: 200.ms).scaleXY(begin: 0.92, end: 1, duration: 300.ms, curve: AppCurves.easeOut);
  }
}

/// Duration helper: zero when reduced motion is on.
Duration motionDuration(BuildContext context, Duration d) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

/// Press feedback: sinks to [scale] immediately on touch (~80ms), springs back
/// on release. Purely visual - the child still handles the tap itself.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97, this.enabled = true});

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 100) : const Duration(milliseconds: 160),
        curve: AppCurves.easeOut,
        child: widget.child,
      ),
    );
  }
}
