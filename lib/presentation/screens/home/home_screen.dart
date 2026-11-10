import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../providers/activity_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/mochi_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/profile_settings_providers.dart';
import '../../widgets/calorie_ring.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';
import '../../widgets/theme_fade.dart';
import '../shell/log_options_sheet.dart';
import 'home_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _maybeCelebrate(DaySummary? prev, DaySummary next) {
    final todayKey = DateTime.now().dayKey;
    if (prev == null || next.dayKey != todayKey || prev.dayKey != todayKey) return;
    final settings = ref.read(settingsProvider);
    if (settings.lastCelebratedDay == todayKey) return;
    final crossed = prev.calorieProgress < 0.95 && next.calorieProgress >= 0.95 && next.calorieProgress <= 1.1;
    if (!crossed) return;
    ref.read(settingsProvider.notifier).markCelebrated(todayKey);
    Haptics.success();
    if (!context.reduceMotion) _confetti.play();
    final social = ref.read(myProfileProvider).value != null;
    showAppSnack(
      context,
      '🎉 Goal reached! Mochi is thrilled.',
      duration: const Duration(seconds: 6),
      actionLabel: 'Share to story',
      // Straight to a progress-card story (or set up a username first).
      onUndo: () => context.push(social ? '/social/story' : '/social'),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedDaySummaryProvider, _maybeCelebrate);
    final summary = ref.watch(selectedDaySummaryProvider);
    final date = ref.watch(selectedDateProvider);
    final name = ref.watch(profileProvider.select((p) => p?.name ?? ''));
    final streak = ref.watch(streakProvider);
    final logged = ref.watch(logsByDayProvider);

    final sections = <Widget>[
      _Header(name: name, streak: streak),
      const _SearchPill(),
      _DayStrip(selected: date, loggedDays: logged.keys.toSet()),
      _MochiHero(summary: summary),
      _MacroRings(summary: summary),
      _SectionTitle(
        title: date.isToday ? 'Meals' : 'Meals · ${date.friendlyLabel}',
        trailing: summary.isEmpty ? null : '${formatKcal(summary.totals.kcal)} kcal',
      ),
      _MealCarousel(summary: summary),
      const _SectionTitle(title: 'Habits'),
      WaterCard(summary: summary),
      NoteCard(summary: summary),
    ];

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: SectionList(
            gap: Space.xl,
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
            children: sections,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            blastDirection: math.pi / 2,
            numberOfParticles: 28,
            gravity: 0.25,
            emissionFrequency: 0.04,
            colors: [
              context.colors.primary,
              context.palette.protein,
              context.palette.carbs,
              context.palette.fat,
              context.palette.water,
            ],
          ),
        ),
      ],
    );
  }
}

Color _outline(BuildContext c) => c.isDark ? BrandColors.darkStrongOutline : BrandColors.lightStrongOutline;

// ---------------------------------------------------------------- Header

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.streak});
  final String name;
  final int streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingFor(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Hello there' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.sm),
        Consumer(
          builder: (context, ref, _) {
            final requests = ref.watch(incomingRequestCountProvider);
            return _RoundButton(
              label: requests > 0 ? 'Friends, $requests new requests' : 'Friends',
              onTap: () {
                Haptics.light();
                context.push('/social');
              },
              child: Badge(
                isLabelVisible: requests > 0,
                label: Text('$requests'),
                child: Icon(Icons.people_alt_rounded, size: 20, color: context.colors.primary),
              ),
            );
          },
        ),
        const SizedBox(width: Space.xs),
        _RoundButton(
          label: dark ? 'Switch to light theme' : 'Switch to dark theme',
          onTap: () {
            Haptics.light();
            ThemeFade.change(
              context,
              () => ref.read(settingsProvider.notifier).setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            );
          },
          child: AnimatedSwitcher(
            duration: motionDuration(context, const Duration(milliseconds: 300)),
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
              size: 20,
              color: dark ? const Color(0xFFFFD27A) : const Color(0xFF6A5ACD),
            ),
          ),
        ),
        const SizedBox(width: Space.xs),
        Semantics(
          label: '$streak day logging streak',
          excludeSemantics: true,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: _outline(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text('$streak', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: context.colors.surface,
          shape: CircleBorder(side: BorderSide(color: _outline(context))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Search pill

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final meal = MealType.forTime(DateTime.now()).name;
    return Pressable(
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
          boxShadow: context.isDark ? null : context.palette.floatShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.pill),
            onTap: () {
              Haptics.light();
              showLogOptionsSheet(context, meal: meal);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 24, color: context.colors.onSurface),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'What did you eat?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _RoundButton(
                    label: 'Snap a photo of your meal',
                    onTap: () {
                      Haptics.light();
                      context.push('/log/photo?meal=$meal');
                    },
                    child: Icon(Icons.photo_camera_rounded, size: 20, color: context.colors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Day strip

class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.selected, required this.loggedDays});
  final DateTime selected;
  final Set<String> loggedDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().dateOnly;
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final index = days.indexWhere((d) => d.isSameDay(selected));
    final notifier = ref.read(selectedDateProvider.notifier);
    final letter = DateFormat('E');

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / 7;
            return Stack(
              children: [
                Row(
                  children: [
                    for (final d in days)
                      SizedBox(
                        width: w,
                        child: Semantics(
                          button: true,
                          selected: d.isSameDay(selected),
                          label: d.friendlyLabel,
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: () {
                              Haptics.tap();
                              notifier.select(d);
                            },
                            radius: 26,
                            child: _DayCell(
                              letter: letter.format(d).substring(0, 1),
                              number: d.day,
                              selected: d.isSameDay(selected),
                              logged: loggedDays.contains(d.dayKey),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (index >= 0)
                  AnimatedPositioned(
                    duration: motionDuration(context, AppDurations.medium),
                    curve: AppCurves.easeInOut,
                    left: index * w + (w - 22) / 2,
                    bottom: 0,
                    width: 22,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.onSurface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Divider(height: 1, color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
        if (index < 0) TextButton(onPressed: notifier.today, child: Text('${selected.friendlyLabel} · Back to today')),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.letter, required this.number, required this.selected, required this.logged});
  final String letter;
  final int number;
  final bool selected;
  final bool logged;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(letter, style: context.text.labelMedium?.copyWith(color: selected ? context.colors.onSurface : muted)),
          const SizedBox(height: 2),
          Text(
            '$number',
            style: context.text.titleMedium?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? context.colors.onSurface : muted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: logged ? context.colors.primary : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Mochi hero

class _MochiHero extends ConsumerWidget {
  const _MochiHero({required this.summary});
  final DaySummary summary;

  static const _moodLabel = {
    MascotMood.happy: 'Feeling good 😊',
    MascotMood.excited: 'Goal hit! 🎉',
    MascotMood.hungry: 'Hungry 🥺',
    MascotMood.thirsty: 'Thirsty 💧',
    MascotMood.stuffed: 'So full 😵',
    MascotMood.sleepy: 'Sleepy 😴',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final mood = moodFor(s);
    // Calories burned from Health Connect (null when not linked).
    final burned = ref.watch(activityProvider(s.dayKey)).value?.activeKcal;
    final countBurned = ref.watch(settingsProvider.select((x) => x.countActivityCalories));
    final budget = s.targets.calories + (countBurned ? (burned ?? 0) : 0);
    final left = budget - s.totals.kcal;
    final over = left < 0;

    // Compact: Mochi in the ring on the left, the numbers on the right.
    return AppCard(
      gradient: BrandSurfaces.hero(context.isDark),
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          CalorieRing(
            consumed: s.totals.kcal,
            goal: budget,
            size: 124,
            strokeWidth: 10,
            onDark: false,
            center: Mascot(mood: mood, size: 88),
          ),
          // Clear breathing room between Mochi's ring and the numbers.
          const SizedBox(width: Space.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.xxs,
                  runSpacing: Space.xxs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: context.isDark ? 0.45 : 0.8),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        _moodLabel[mood]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium,
                      ),
                    ),
                    const _LevelPill(),
                  ],
                ),
                const SizedBox(height: Space.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUpText(
                    value: left.abs(),
                    style: context.text.displaySmall?.copyWith(
                      color: over ? context.palette.warning : context.colors.onSurface,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  over ? 'kcal over' : 'kcal left',
                  maxLines: 1,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.md),
                _StatLine(icon: Icons.restaurant_rounded, label: 'Eaten', value: formatKcal(s.totals.kcal)),
                const SizedBox(height: Space.xs),
                _StatLine(icon: Icons.flag_rounded, label: 'Goal', value: formatKcal(budget)),
                if (burned != null) ...[
                  const SizedBox(height: Space.xs),
                  _StatLine(icon: Icons.local_fire_department_rounded, label: 'Burned', value: formatKcal(burned)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value calories',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.primary),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: Space.xs),
          Text(
            value,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Macro rings

class _MacroRings extends StatelessWidget {
  const _MacroRings({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = summary.totals;
    final t = summary.targets;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.sm),
      child: Row(
        children: [
          _MacroRing(label: 'Protein', value: m.protein, goal: t.protein, color: p.protein),
          _MacroRing(label: 'Carbs', value: m.carbs, goal: t.carbs, color: p.carbs),
          _MacroRing(label: 'Fat', value: m.fat, goal: t.fat, color: p.fat),
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({required this.label, required this.value, required this.goal, required this.color});
  final String label;
  final double value;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    return Expanded(
      child: Semantics(
        label: '$label ${value.round()} of $goal grams',
        excludeSemantics: true,
        child: Column(
          children: [
            SizedBox.square(
              dimension: 68,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: motionDuration(context, AppDurations.ring),
                curve: AppCurves.easeOut,
                builder: (context, v, child) => CustomPaint(
                  painter: _ArcPainter(progress: v, color: color),
                  child: child,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${value.round()}', style: context.text.titleLarge),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge),
            Text(
              '/ ${goal}g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.16),
    );
    // A tiny sweep with a round cap draws a starting dot when progress is 0.
    {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * math.max(progress.clamp(0.0, 1.0), 0.0001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.progress != progress || o.color != color;
}

// ----------------------------------------------------------------- Meals

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineSmall),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Space.sm),
            Text(trailing!, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Soft per-meal tint for the card "photo" area.
Color _mealTint(BuildContext context, MealType m) {
  final dark = context.isDark;
  return switch (m) {
    MealType.breakfast => dark ? const Color(0xFF3A3222) : const Color(0xFFFFEBC7),
    MealType.lunch => dark ? const Color(0xFF1D3A33) : const Color(0xFFDDF5E6),
    MealType.dinner => dark ? const Color(0xFF2A2F62) : const Color(0xFFE4E5FF),
    MealType.snack => dark ? const Color(0xFF412648) : const Color(0xFFFFE1EB),
  };
}

/// Swipeable row of big, visual meal cards.
class _MealCarousel extends StatelessWidget {
  const _MealCarousel({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: MealType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final meal = MealType.values[i];
          return _MealCard(meal: meal, logs: summary.byMeal[meal]!);
        },
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.logs});
  final MealType meal;
  final List<FoodLog> logs;

  @override
  Widget build(BuildContext context) {
    final kcal = logs.fold<double>(0, (a, l) => a + l.food.macros.kcal);
    final emojis = logs.map((l) => l.food.emoji).toSet().take(3).toList();

    return SizedBox(
      width: 156,
      child: AppCard(
        padding: const EdgeInsets.all(Space.xs),
        semanticLabel: logs.isEmpty
            ? '${meal.label}, nothing logged. Tap to add'
            : '${meal.label}, ${formatKcal(kcal)} calories, ${logs.length} items. Tap to open',
        onTap: () {
          Haptics.light();
          logs.isEmpty ? showLogOptionsSheet(context, meal: meal.name) : _openMealSheet(context, meal);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 128,
              width: double.infinity,
              decoration: BoxDecoration(color: _mealTint(context, meal), borderRadius: Radii.smAll),
              child: logs.isEmpty
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(meal.icon, size: 44, color: context.colors.onSurface.withValues(alpha: 0.25)),
                        Positioned(
                          right: Space.xs,
                          bottom: Space.xs,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                            child: Icon(Icons.add_rounded, size: 20, color: context.colors.onPrimary),
                          ),
                        ),
                      ],
                    )
                  : Center(child: _EmojiStack(emojis: emojis)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  Text(
                    logs.isEmpty ? 'Tap to add' : '${formatKcal(kcal)} kcal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiStack extends StatelessWidget {
  const _EmojiStack({required this.emojis});
  final List<String> emojis;

  @override
  Widget build(BuildContext context) {
    if (emojis.length == 1) return Text(emojis.first, style: const TextStyle(fontSize: 58), semanticsLabel: '');
    final sizes = [46.0, 38.0, 32.0];
    final offsets = [const Offset(-22, -12), const Offset(22, 6), const Offset(-6, 26)];
    return SizedBox(
      width: 120,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = emojis.length - 1; i >= 0; i--)
            Transform.translate(
              offset: offsets[i],
              child: Text(
                emojis[i],
                style: TextStyle(fontSize: sizes[i]),
                semanticsLabel: '',
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing one meal's foods: tap to edit, swipe to delete.
Future<void> _openMealSheet(BuildContext context, MealType meal) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, controller) => Consumer(
        builder: (ctx, ref, _) {
          final s = ref.watch(selectedDaySummaryProvider);
          final logs = s.byMeal[meal]!;
          final kcal = logs.fold<double>(0, (a, l) => a + l.food.macros.kcal);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: _mealTint(ctx, meal), borderRadius: Radii.smAll),
                    child: Icon(meal.icon, color: ctx.colors.onSurface),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meal.label, style: ctx.text.headlineSmall),
                        Text(
                          '${formatKcal(kcal)} kcal',
                          style: ctx.text.bodyMedium?.copyWith(color: ctx.colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (logs.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (v) async {
                        if (v == 'template') {
                          await saveMealAsTemplate(ctx, ref, meal, logs);
                        } else if (v == 'clear') {
                          final removed = [...logs];
                          Haptics.warning();
                          await ref.read(logsProvider.notifier).removeAll(removed.map((l) => l.id));
                          if (ctx.mounted) {
                            showAppSnack(
                              ctx,
                              '${meal.label} cleared',
                              onUndo: () => ref.read(logsProvider.notifier).restore(removed),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'template', child: Text('Save as template')),
                        PopupMenuItem(value: 'clear', child: Text('Clear meal')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Space.xl),
                  child: Center(child: Mascot(mood: MascotMood.hungry, size: 110, interactive: false)),
                )
              else
                for (final log in logs) _FoodRow(key: ValueKey(log.id), log: log),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showLogOptionsSheet(context, meal: meal.name);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('Add to ${meal.label.toLowerCase()}'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FoodRow extends ConsumerWidget {
  const _FoodRow({super.key, required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = log.food;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xxs),
      child: SwipeToDelete(
        dismissKey: ValueKey('dismiss-${log.id}'),
        onDelete: () {
          ref.read(logsProvider.notifier).remove(log.id);
          showAppSnack(context, 'Removed ${f.name}', onUndo: () => ref.read(logsProvider.notifier).restore([log]));
        },
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: () => showEditLogSheet(context, ref, log),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.md, Space.xs),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.isDark ? BrandColors.darkSurfaceHigh : BrandColors.lightSurfaceHigh,
                    borderRadius: Radii.smAll,
                  ),
                  child: Text(f.emoji, style: const TextStyle(fontSize: 28), semanticsLabel: ''),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${formatMultiplier(f.multiplier)} × ${f.servingLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(formatKcal(f.macros.kcal), style: context.text.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mochi's level; opens the wardrobe.
class _LevelPill extends ConsumerWidget {
  const _LevelPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(mochiProgressProvider.select((p) => p.level));
    return Semantics(
      button: true,
      label: 'Mochi level $level. Open wardrobe',
      excludeSemantics: true,
      child: Pressable(
        child: GestureDetector(
          onTap: () {
            Haptics.light();
            context.push('/mochi');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFC94D), Color(0xFFF08A24)]),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              'Lv $level',
              style: context.text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
