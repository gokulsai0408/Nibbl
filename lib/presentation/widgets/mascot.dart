import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/services/sound_fx.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/mochi.dart';
import '../providers/log_providers.dart';
import '../providers/mochi_providers.dart';
import 'mochi_wardrobe_paint.dart';

/// Mochi's mood, derived from the user's day.
enum MascotMood { happy, excited, hungry, thirsty, stuffed, sleepy }

/// Picks Mochi's mood from today's numbers and the time of day.
MascotMood moodFor(DaySummary s, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final isToday =
      s.dayKey ==
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  if (!isToday) return s.isEmpty ? MascotMood.sleepy : MascotMood.happy;
  final p = s.calorieProgress;
  if (p > 1.1) return MascotMood.stuffed;
  if (p >= 0.9) return MascotMood.excited;
  if (t.hour >= 22 || t.hour < 5) return MascotMood.sleepy;
  if (s.isEmpty && t.hour >= 10) return MascotMood.hungry;
  if (t.hour >= 14 && s.meta.waterMl < s.waterGoalMl * 0.4) return MascotMood.thirsty;
  return MascotMood.happy;
}

/// What Mochi says. Tapping cycles through these.
List<String> mascotLines(MascotMood mood, DaySummary s) {
  final left = s.remainingKcal.round();
  final protein = (s.targets.protein - s.totals.protein).round();
  final water = s.meta.waterMl;
  return switch (mood) {
    MascotMood.happy => [
      if (left > 0) 'You\'ve got $left kcal left today. We\'re doing great!',
      if (protein > 15) 'Psst… ${protein}g of protein to go. Eggs? Yogurt? Chicken?',
      'Snap your next meal and I\'ll do the math 📸',
      'I believe in you. And in snacks. Mostly you.',
    ],
    MascotMood.excited => [
      'Goal reached! I\'m so proud I could bounce! 🎉',
      'Right on target today. High five! ✋',
      'That\'s what balance looks like. Nailed it.',
    ],
    MascotMood.hungry => [
      'My tummy\'s rumbling… what are we eating today?',
      'Nothing logged yet! Tap + and show me your plate.',
      'Breakfast, brunch, anything? I\'m starving here 🥺',
    ],
    MascotMood.thirsty => [
      'Only ${(water / 1000).toStringAsFixed(1)} L of water so far. Glass of water? 💧',
      'I\'m feeling a bit dry… sip sip?',
      'Water break! Your future self says thanks.',
    ],
    MascotMood.stuffed => [
      'Oof, we\'re ${(-left).abs()} kcal over. No stress, tomorrow\'s a fresh start.',
      'So full… maybe a little walk? 🚶',
      'One day doesn\'t undo progress. Lighter dinner tomorrow?',
    ],
    MascotMood.sleepy => [
      'Zzz… it\'s late. Good night, see you at breakfast.',
      'Sleep helps your goals too. Rest up! 😴',
      'Yawn… log tomorrow\'s breakfast with me?',
    ],
  };
}

/// Mochi: a cute, interactive mascot. Breathes, blinks, sways its sprout,
/// squishes and floats hearts when tapped, hops on long-press.
class Mascot extends ConsumerStatefulWidget {
  const Mascot({
    super.key,
    required this.mood,
    this.size = 120,
    this.onTap,
    this.onLongPress,
    this.onTickle,
    this.interactive = true,
    this.outfit,
    this.stage,
  });

  final MascotMood mood;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Called (throttled) while the user rubs Mochi side to side.
  final VoidCallback? onTickle;
  final bool interactive;

  /// Accessories to wear. Null = what the user equipped in the wardrobe.
  final Set<MochiItem>? outfit;

  /// Growth stage of the sprout. Null = the user's current level.
  final MochiStage? stage;

  @override
  ConsumerState<Mascot> createState() => _MascotState();
}

class _MascotState extends ConsumerState<Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  late final AnimationController _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _hearts = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  late final AnimationController _lookBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Offset _look = Offset.zero;
  DateTime _lastTickle = DateTime(2000);
  double _rubDistance = 0;
  final _rng = math.Random();
  Timer? _blinkTimer;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduce && (_idle.isAnimating || reduce)) return;
    _reduce = reduce;
    if (reduce) {
      _idle.stop();
      _blinkTimer?.cancel();
    } else {
      _idle.repeat();
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _rng.nextInt(2600)), () async {
      if (!mounted) return;
      await _blink.forward();
      if (!mounted) return;
      await _blink.reverse();
      // Occasional double blink.
      if (mounted && _rng.nextDouble() < 0.25) {
        await _blink.forward();
        if (mounted) await _blink.reverse();
      }
      if (mounted) _scheduleBlink();
    });
  }

  void _tap() {
    Haptics.light();
    SoundFx.squeak();
    if (_reduce) {
      _squish.forward(from: 0.5);
    } else {
      _hop.forward(from: 0);
    }
    _hearts.forward(from: 0);
    widget.onTap?.call();
  }

  void _track(Offset local) {
    final r = widget.size / 2;
    _lookBack.stop();
    _lookBack.value = 0;
    setState(() {
      _look = Offset(((local.dx - r) / r).clamp(-1.0, 1.0), ((local.dy - r) / r).clamp(-1.0, 1.0));
    });
  }

  void _rub(DragUpdateDetails d) {
    _track(d.localPosition);
    _rubDistance += d.delta.dx.abs();
    final now = DateTime.now();
    if (_rubDistance > 60 && now.difference(_lastTickle).inMilliseconds > 450) {
      _rubDistance = 0;
      _lastTickle = now;
      Haptics.tap();
      SoundFx.giggle();
      _squish.forward(from: 0.15);
      widget.onTickle?.call();
    }
  }

  void _release([Object? _]) {
    _rubDistance = 0;
    _lookBack.forward(from: 0);
  }

  Future<void> _longPress() async {
    Haptics.medium();
    SoundFx.boing();
    _hearts.forward(from: 0);
    widget.onLongPress?.call();
    if (_reduce) return;
    // Double jump.
    await _hop.forward(from: 0);
    if (mounted) await _hop.forward(from: 0);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _squish.dispose();
    _hearts.dispose();
    _hop.dispose();
    _lookBack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Set<MochiItem> outfit = widget.outfit ?? ref.watch(mochiOutfitProvider);
    final MochiStage stage = widget.stage ?? ref.watch(mochiProgressProvider.select((p) => p.stage));
    final paint = RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _blink, _squish, _hearts, _hop, _lookBack]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _MascotPainter(
            mood: widget.mood,
            idle: _idle.value,
            blink: _blink.value,
            squish: _squish.value,
            hearts: _hearts.value,
            hop: _hop.value,
            look: _look * (1 - Curves.easeOut.transform(_lookBack.value)),
            dark: context.isDark,
            outfit: outfit,
            stage: stage,
          ),
        ),
      ),
    );
    if (!widget.interactive) return ExcludeSemantics(child: paint);
    return Semantics(
      button: true,
      label: 'Mochi, your food buddy. Feeling ${widget.mood.name}. Tap to chat',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        onLongPress: _longPress,
        // Horizontal rubs tickle Mochi; vertical swipes still scroll the page.
        onHorizontalDragStart: (d) => _track(d.localPosition),
        onHorizontalDragUpdate: _rub,
        onHorizontalDragEnd: _release,
        onHorizontalDragCancel: _release,
        child: paint,
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.mood,
    required this.idle,
    required this.blink,
    required this.squish,
    required this.hearts,
    required this.hop,
    required this.look,
    required this.dark,
    required this.outfit,
    required this.stage,
  });

  final Offset look;
  final MascotMood mood;
  final double idle;
  final double blink;
  final double squish;
  final double hearts;
  final double hop;
  final bool dark;
  final Set<MochiItem> outfit;
  final MochiStage stage;

  static const _ink = Color(0xFF2B2B2B);
  static const _cheek = Color(0xFFFF9AA8);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final breathe = (math.sin(idle * math.pi * 2) + 1) / 2; // 0..1
    // Damped wobble after a tap.
    final wob = squish == 0 ? 0.0 : math.sin(squish * math.pi * 3) * (1 - squish);
    final (hopY, jumpSx, jumpSy) = _jump(hop, s);

    final scaleX = (1 + 0.12 * wob - 0.01 * breathe) * jumpSx;
    final scaleY = (1 - 0.12 * wob + 0.025 * breathe) * jumpSy;
    final groundY = s * 0.9;

    // Ground shadow shrinks while hopping.
    final shadowW = s * 0.56 * (1 + hopY / s);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s / 2, groundY), width: shadowW, height: s * 0.07),
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
    );

    canvas.save();
    // Squash & stretch anchored at the feet.
    canvas.translate(s / 2, groundY + hopY - breathe * s * 0.01);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-s / 2, -groundY);

    // Little arms (behind the body). They wave when Mochi is excited or happy-tapped.
    final waving = mood == MascotMood.excited || hearts > 0 || hop > 0;
    final wave = waving ? math.sin(idle * math.pi * 2 * 4) * 0.55 : math.sin(idle * math.pi * 2) * 0.08;
    final armPaint = Paint()..color = const Color(0xFFB4EBD0);
    for (final dir in [-1, 1]) {
      canvas.save();
      canvas.translate(s * (0.5 + dir * 0.36), s * 0.66);
      canvas.rotate(dir * (0.5 + (dir < 0 ? wave : -wave * 0.6)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(dir * s * 0.05, -s * 0.02), width: s * 0.16, height: s * 0.1),
          Radius.circular(s * 0.05),
        ),
        armPaint,
      );
      canvas.restore();
    }

    // Body: a soft mochi blob.
    final body = Rect.fromLTWH(s * 0.12, s * 0.28, s * 0.76, s * 0.62);
    final bodyPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          body,
          topLeft: Radius.elliptical(s * 0.38, s * 0.36),
          topRight: Radius.elliptical(s * 0.38, s * 0.36),
          bottomLeft: Radius.elliptical(s * 0.26, s * 0.2),
          bottomRight: Radius.elliptical(s * 0.26, s * 0.2),
        ),
      );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4FFF9), Color(0xFFC6F2DD)],
        ).createShader(body),
    );
    // Soft rim to give volume.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = const Color(0xFF8FD9B6).withValues(alpha: 0.7),
    );
    // Shine.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.33, s * 0.4), width: s * 0.13, height: s * 0.07),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Sprout on top, gently swaying. It grows as Mochi levels up.
    final sway = math.sin(idle * math.pi * 2 + 1.2) * 0.14 + wob * 0.4;
    if (!outfit.any((i) => i.coversSprout)) {
      canvas.save();
      canvas.translate(s * 0.5, s * 0.29);
      canvas.rotate(sway);
      MochiWardrobePaint.sprout(canvas, s, stage);
      canvas.restore();
    }

    // The face shifts slightly toward wherever the finger is.
    final eyeY = s * 0.56 + look.dy * s * 0.02;
    final eyeDx = s * 0.13;
    final cx = s / 2 + look.dx * s * 0.035;

    // Cheeks.
    final cheekPaint = Paint()..color = _cheek.withValues(alpha: mood == MascotMood.stuffed ? 0.85 : 0.6);
    for (final dir in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + dir * s * 0.235, eyeY + s * 0.075), width: s * 0.11, height: s * 0.065),
        cheekPaint,
      );
    }

    // Eyes.
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.024
      ..strokeCap = StrokeCap.round;
    final closedHappy = mood == MascotMood.excited || wob.abs() > 0.35;
    for (final dir in [-1, 1]) {
      final c = Offset(cx + dir * eyeDx, eyeY);
      if (mood == MascotMood.sleepy) {
        canvas.drawLine(c.translate(-s * 0.035, 0), c.translate(s * 0.035, 0), line);
      } else if (closedHappy) {
        // ^ ^ happy eyes
        final p = Path()
          ..moveTo(c.dx - s * 0.04, c.dy + s * 0.012)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.05, c.dx + s * 0.04, c.dy + s * 0.012);
        canvas.drawPath(p, line);
      } else if (mood == MascotMood.stuffed) {
        // > < squinty
        canvas.drawLine(c.translate(-s * 0.03, -s * 0.025), c.translate(s * 0.02 * dir, 0), line);
        canvas.drawLine(c.translate(s * 0.02 * dir, 0), c.translate(-s * 0.03, s * 0.025), line);
      } else {
        final h = s * 0.1 * (1 - blink * 0.9);
        canvas.drawOval(Rect.fromCenter(center: c, width: s * 0.075, height: h), ink);
        if (blink < 0.5) {
          canvas.drawCircle(c.translate(-s * 0.012, -h * 0.22), s * 0.014, Paint()..color = Colors.white);
        }
      }
    }

    // Mouth.
    final m = Offset(cx, eyeY + s * 0.085);
    switch (mood) {
      case MascotMood.excited:
        final p = Path()
          ..moveTo(m.dx - s * 0.07, m.dy - s * 0.01)
          ..quadraticBezierTo(m.dx, m.dy + s * 0.11, m.dx + s * 0.07, m.dy - s * 0.01)
          ..close();
        canvas.drawPath(p, ink);
        canvas.drawOval(
          Rect.fromCenter(center: m.translate(0, s * 0.035), width: s * 0.06, height: s * 0.03),
          Paint()..color = const Color(0xFFFF7A8A),
        );
      case MascotMood.hungry:
        canvas.drawOval(Rect.fromCenter(center: m.translate(0, s * 0.01), width: s * 0.045, height: s * 0.055), ink);
      case MascotMood.stuffed:
        final p = Path()..moveTo(m.dx - s * 0.06, m.dy);
        for (var i = 0; i < 4; i++) {
          p.relativeQuadraticBezierTo(s * 0.015, (i.isEven ? -1 : 1) * s * 0.02, s * 0.03, 0);
        }
        canvas.drawPath(p, line);
      case MascotMood.sleepy:
        canvas.drawOval(Rect.fromCenter(center: m, width: s * 0.03, height: s * 0.03), ink);
      case MascotMood.thirsty:
        canvas.drawLine(m.translate(-s * 0.03, 0), m.translate(s * 0.03, 0), line);
      case MascotMood.happy:
        final p = Path()
          ..moveTo(m.dx - s * 0.05, m.dy - s * 0.005)
          ..quadraticBezierTo(m.dx, m.dy + s * 0.055, m.dx + s * 0.05, m.dy - s * 0.005);
        canvas.drawPath(p, line);
    }

    // Wardrobe.
    if (outfit.isNotEmpty) {
      MochiWardrobePaint.faceItems(canvas, s, outfit, cx: cx, eyeY: eyeY);
      MochiWardrobePaint.bodyItems(canvas, s, outfit, bodyPath, sway: sway);
    }
    canvas.restore();

    // Mood accessories (outside the squash transform).
    if (mood == MascotMood.sleepy) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(fontSize: s * 0.12, fontWeight: FontWeight.w800, color: const Color(0xFF8A8FB8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final float = idle * s * 0.06;
      tp.paint(canvas, Offset(s * 0.78, s * 0.26 - float));
    }
    if (mood == MascotMood.thirsty) {
      _drop(canvas, Offset(s * 0.83, s * 0.33 + math.sin(idle * math.pi * 2) * s * 0.02), s * 0.06);
    }
    if (mood == MascotMood.hungry) {
      // Little sweat drop.
      _drop(canvas, Offset(s * 0.8, s * 0.42), s * 0.045, color: const Color(0xFF9AD8F5));
    }

    // Hearts after a tap.
    if (hearts > 0 && hearts < 1) {
      const seeds = [(-0.22, 0.0), (0.18, 0.12), (0.02, 0.25), (-0.06, 0.38)];
      for (final (dx, delay) in seeds) {
        final t = ((hearts - delay) / (1 - delay)).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final pos = Offset(s * (0.5 + dx + math.sin(t * 6) * 0.03), s * (0.32 - t * 0.32));
        _heart(canvas, pos, s * 0.07 * (0.6 + t * 0.5), (1 - t).clamp(0, 1));
      }
    }
  }

  /// Cartoon jump: crouch -> launch (stretch) -> land (squash) -> settle.
  /// Returns (vertical offset, scaleX, scaleY).
  static (double, double, double) _jump(double t, double s) {
    if (t <= 0 || t >= 1) return (0, 1, 1);
    if (t < 0.18) {
      final k = Curves.easeOut.transform(t / 0.18);
      return (0, 1 + 0.12 * k, 1 - 0.16 * k);
    }
    if (t < 0.62) {
      final k = (t - 0.18) / 0.44;
      final c = math.cos(k * math.pi);
      return (-math.sin(k * math.pi) * s * 0.3, 1 - 0.06 * c, 1 + 0.09 * c);
    }
    if (t < 0.78) {
      final m = math.sin((t - 0.62) / 0.16 * math.pi);
      return (0, 1 + 0.14 * m, 1 - 0.18 * m);
    }
    final k = (t - 0.78) / 0.22;
    final w = math.sin(k * math.pi * 2) * (1 - k);
    return (0, 1 - 0.04 * w, 1 + 0.05 * w);
  }

  void _drop(Canvas canvas, Offset c, double r, {Color color = const Color(0xFF2EB5F0)}) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r * 1.4)
      ..quadraticBezierTo(c.dx + r, c.dy - r * 0.2, c.dx + r * 0.85, c.dy + r * 0.3)
      ..arcToPoint(Offset(c.dx - r * 0.85, c.dy + r * 0.3), radius: Radius.circular(r * 0.9))
      ..quadraticBezierTo(c.dx - r, c.dy - r * 0.2, c.dx, c.dy - r * 1.4);
    canvas.drawPath(p, Paint()..color = color);
  }

  void _heart(Canvas canvas, Offset c, double r, double opacity) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.1, c.dx - r * 0.6, c.dy - r * 1.1, c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.1, c.dx + r * 1.4, c.dy - r * 0.1, c.dx, c.dy + r * 0.9);
    canvas.drawPath(p, Paint()..color = const Color(0xFFFF5C7A).withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(_MascotPainter o) =>
      o.mood != mood ||
      o.idle != idle ||
      o.blink != blink ||
      o.squish != squish ||
      o.hearts != hearts ||
      o.hop != hop ||
      o.look != look ||
      o.dark != dark ||
      o.stage != stage ||
      !setEquals(o.outfit, outfit);
}

/// Rounded speech bubble with a tail pointing up toward Mochi.
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text, this.centerTail = false});
  final String text;

  /// Tail in the middle (Mochi above) instead of near the left edge.
  final bool centerTail;

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? BrandColors.darkSurfaceHigh : BrandColors.lightSurfaceHigh;
    return Semantics(
      liveRegion: true,
      label: 'Mochi says: $text',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: centerTail ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: centerTail ? 0 : 56),
            child: CustomPaint(size: const Size(18, 9), painter: _TailPainter(bg)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.medium,
              switchInCurve: AppCurves.easeOut,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: centerTail ? Alignment.topCenter : Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                text,
                key: ValueKey(text),
                textAlign: centerTail ? TextAlign.center : TextAlign.start,
                style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter o) => o.color != color;
}
