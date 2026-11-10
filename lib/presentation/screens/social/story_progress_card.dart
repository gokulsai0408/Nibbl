import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/mochi.dart';
import '../../../domain/entities/social.dart';
import '../../widgets/mascot.dart';

/// A story made from the day's numbers: Mochi (in the author's outfit), the
/// streak and three goal rings. Designed for a tall, full-screen canvas.
class StoryProgressCard extends StatelessWidget {
  const StoryProgressCard({super.key, required this.progress, this.caption = '', this.compact = false});
  final StoryProgress progress;
  final String caption;

  /// Smaller version for previews.
  final bool compact;

  static const _goalColors = [Color(0xFFFF8A5B), Color(0xFFFF5C8A), Color(0xFF7C5CFF)];
  static const _calmColors = [Color(0xFF2BB673), Color(0xFF14A3A3), Color(0xFF2D6CDF)];

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final hits = [p.calorieGoalHit, p.proteinGoalHit, p.waterGoalHit].where((h) => h).length;
    final outfit = {for (final o in p.outfit) ?MochiItem.byName(o)};
    final mood = hits >= 2 ? MascotMood.excited : MascotMood.happy;
    final scale = compact ? 0.62 : 1.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hits >= 2 ? _goalColors : _calmColors,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Three rings (+ label width) must fit inside the horizontal padding.
          final inner = c.maxWidth - 48 * scale;
          final ring = math.min(inner / 3 - 20, 104.0);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 20 * scale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---- Streak
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    p.streak > 0 ? 'Day ${p.streak} 🔥' : 'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      shadows: const [Shadow(color: Color(0x33000000), blurRadius: 8)],
                    ),
                  ),
                ),
                if (hits > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4 * scale),
                    child: Text(
                      hits == 3 ? 'Every goal hit today 🏆' : '$hits of 3 goals hit',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SizedBox(height: 16 * scale),

                // ---- Mochi
                Mascot(
                  mood: mood,
                  size: (compact ? 120 : 190).toDouble(),
                  outfit: outfit,
                  stage: MochiStage.forLevel(p.mochiLevel),
                  interactive: false,
                ),
                Container(
                  margin: EdgeInsets.only(top: 6 * scale),
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Mochi · Lv ${p.mochiLevel}',
                    style: TextStyle(color: Colors.white, fontSize: 13 * scale, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 22 * scale),

                // ---- Rings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Ring(
                      size: ring,
                      value: p.kcalGoal == 0 ? 0 : p.kcal / p.kcalGoal,
                      top: '${p.kcal}',
                      bottom: 'of ${p.kcalGoal} kcal',
                      hit: p.calorieGoalHit,
                      scale: scale,
                    ),
                    _Ring(
                      size: ring,
                      value: p.proteinGoal == 0 ? 0 : p.protein / p.proteinGoal,
                      top: '${p.protein}g',
                      bottom: 'protein',
                      hit: p.proteinGoalHit,
                      scale: scale,
                    ),
                    _Ring(
                      size: ring,
                      value: p.waterGoalMl == 0 ? 0 : p.waterMl / p.waterGoalMl,
                      top: (p.waterMl / 1000).toStringAsFixed(1),
                      bottom: 'L water',
                      hit: p.waterGoalHit,
                      scale: scale,
                    ),
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  SizedBox(height: 22 * scale),
                  Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6)],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.value,
    required this.top,
    required this.bottom,
    required this.hit,
    required this.scale,
  });

  final double size;
  final double value;
  final String top;
  final String bottom;
  final bool hit;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 8 * scale,
                  strokeCap: StrokeCap.round,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(12 * scale),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hit ? '$top ✓' : top,
                      style: TextStyle(color: Colors.white, fontSize: 20 * scale, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6 * scale),
        SizedBox(
          width: size + 12,
          child: Text(
            bottom,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
