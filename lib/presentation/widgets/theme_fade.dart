import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Smooth light/dark switching for the whole app.
///
/// Lerping [ThemeData] alone looks broken: Material colors blend, but anything
/// keyed off `brightness` (gradients, outlines, the backdrop, the status bar)
/// snaps halfway through. Instead we screenshot the current frame, lay it on
/// top, switch the theme instantly underneath, and fade the screenshot out —
/// so every pixel transitions together.
class ThemeFade extends StatefulWidget {
  const ThemeFade({super.key, required this.child});
  final Widget child;

  /// Runs [apply] (which should change the theme) behind a cross-fade.
  static Future<void> change(BuildContext context, FutureOr<void> Function() apply) {
    final state = context.findAncestorStateOfType<_ThemeFadeState>();
    if (state == null) return Future.sync(apply);
    return state._run(apply);
  }

  @override
  State<ThemeFade> createState() => _ThemeFadeState();
}

class _ThemeFadeState extends State<ThemeFade> with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 0);
  ui.Image? _snapshot;
  double _pixelRatio = 1;

  Future<void> _run(FutureOr<void> Function() apply) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (_snapshot != null || boundary == null || MediaQuery.disableAnimationsOf(context)) {
      await apply();
      return;
    }

    ui.Image image;
    try {
      _pixelRatio = MediaQuery.devicePixelRatioOf(context);
      image = await boundary.toImage(pixelRatio: _pixelRatio);
    } catch (_) {
      await apply();
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }

    setState(() => _snapshot = image);
    _fade.value = 1;
    await apply();
    // Let the new theme paint underneath before revealing it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _fade.animateTo(0, curve: Curves.easeInOutCubic);
    if (!mounted) return;
    setState(() => _snapshot = null);
    image.dispose();
  }

  @override
  void dispose() {
    _fade.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _fade,
                child: RawImage(image: snapshot, scale: _pixelRatio, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
