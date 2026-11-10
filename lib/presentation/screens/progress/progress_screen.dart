import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/tracking.dart';
import '../../providers/profile_settings_providers.dart';
import '../../providers/progress_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/motion.dart';
import '../onboarding/onboarding_widgets.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(progressRangeProvider);
    final stats = ref.watch(progressStatsProvider);

    final sections = <Widget>[
      Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text('Progress', style: context.text.headlineMedium)),
          ),
          SegmentedButton<ProgressRange>(
            showSelectedIcon: false,
            segments: [for (final r in ProgressRange.values) ButtonSegment(value: r, label: Text(r.label))],
            selected: {range},
            onSelectionChanged: (s) {
              Haptics.tap();
              ref.read(progressRangeProvider.notifier).set(s.first);
            },
          ),
        ],
      ),
      _SummaryCard(stats: stats),
      const _WeightCard(),
      _CaloriesCard(stats: stats),
      _MacroTrendCard(stats: stats),
    ];

    return SafeArea(
      bottom: false,
      child: SectionList(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.navClearance),
        children: sections,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});
  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasData) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Average vs goal', style: context.text.titleMedium),
            const SizedBox(height: Space.md),
            const InlineEmpty(
              icon: Icons.insights_rounded,
              title: 'No data yet',
              message: 'Log meals to see your averages.',
            ),
          ],
        ),
      );
    }
    final diff = stats.avg.kcal - stats.goalKcal;
    Widget tile(String label, Widget value, String caption, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: context.colors.surfaceContainerLow, borderRadius: Radii.mdAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: Space.xxs),
            value,
            Text(caption, style: context.text.bodySmall?.copyWith(color: color)),
          ],
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average vs goal', style: context.text.titleMedium),
          const SizedBox(height: Space.md),
          Row(
            children: [
              tile(
                'Avg calories',
                CountUpText(value: stats.avg.kcal, style: context.text.headlineSmall),
                diff.abs() < stats.goalKcal * 0.05
                    ? 'On target'
                    : '${diff > 0 ? '+' : '−'}${formatKcal(diff.abs())} vs ${formatKcal(stats.goalKcal)}',
                diff.abs() < stats.goalKcal * 0.1 ? context.palette.success : context.palette.warning,
              ),
              const SizedBox(width: Space.sm),
              tile(
                'Avg protein',
                CountUpText(value: stats.avg.protein, suffix: 'g', style: context.text.headlineSmall),
                'Goal ${stats.goalProtein}g',
                context.colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              tile(
                'Days logged',
                CountUpText(value: stats.daysLogged, style: context.text.headlineSmall),
                'of ${stats.days.length}',
                context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: Space.sm),
              tile(
                'On target',
                CountUpText(value: stats.daysOnTarget, style: context.text.headlineSmall),
                'within ±10%',
                context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weights = ref.watch(weightsProvider);
    final target = ref.watch(profileProvider.select((p) => p?.targetWeightKg));
    final latest = weights.lastOrNull;
    final change = weights.length >= 2 ? weights.last.kg - weights.first.kg : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight', style: context.text.titleMedium),
                    if (latest != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: latest.kg.toStringAsFixed(1), style: context.text.headlineSmall),
                            TextSpan(text: ' kg', style: context.text.bodyMedium),
                            if (change != null)
                              TextSpan(
                                text: '   ${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg total',
                                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _logWeight(context, ref, latest?.kg ?? ref.read(profileProvider)?.weightKg ?? 70),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Log'),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (weights.isEmpty)
            const InlineEmpty(
              icon: Icons.monitor_weight_outlined,
              title: 'No weigh-ins yet',
              message: 'Tap Log to add today’s weight.',
            )
          else ...[
            if (target != null) ...[
              // Key for the dashed goal line (kept off the chart so it never
              // collides with the line or the data points).
              Row(
                children: [
                  CustomPaint(size: const Size(22, 2), painter: _DashPainter(context.palette.success)),
                  const SizedBox(width: 6),
                  Text(
                    'Goal ${target.toStringAsFixed(1)} kg',
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
            SizedBox(
              height: 180,
              child: _WeightChart(weights: weights, target: target),
            ),
          ],
          if (weights.length > 1) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Long-press a point for details.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logWeight(BuildContext context, WidgetRef ref, double initial) async {
    var value = (initial * 2).round() / 2;
    final result = await showModalBottomSheet<double>(
      context: context,
      sheetAnimationStyle: kSheetAnimation,
      useRootNavigator: true, // open above the floating nav bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Log today\'s weight', style: ctx.text.titleLarge),
              const SizedBox(height: Space.lg),
              NumberPicker(
                label: 'Weight',
                value: value,
                min: 35,
                max: 250,
                step: 0.1,
                decimals: 1,
                unit: 'kg',
                onChanged: (v) => setState(() => value = v),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    await ref.read(weightsProvider.notifier).log(double.parse(result.toStringAsFixed(1)));
    Haptics.success();
    if (context.mounted) showAppSnack(context, 'Weight logged: ${result.toStringAsFixed(1)} kg');
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.weights, required this.target});
  final List<WeightEntry> weights;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    final first = weights.first.date.dateOnly;
    final spots = [for (final w in weights) FlSpot(w.date.dateOnly.difference(first).inDays.toDouble(), w.kg)];
    final values = [...weights.map((w) => w.kg), ?target];
    final minY = (values.reduce(math.min) - 2).floorToDouble();
    final maxY = (values.reduce(math.max) + 2).ceilToDouble();
    final maxX = math.max(spots.last.x, 1).toDouble();
    final fmt = DateFormat('d MMM');

    return Semantics(
      label: 'Weight chart from ${weights.first.kg} to ${weights.last.kg} kilograms',
      child: LineChart(
        duration: motionDuration(context, AppDurations.slow),
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: maxX,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: math.max(((maxY - minY) / 4).roundToDouble(), 1),
            getDrawingHorizontalLine: (_) => FlLine(color: context.colors.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: math.max(((maxY - minY) / 4).roundToDouble(), 1),
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(v.toStringAsFixed(0), style: context.text.labelSmall),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: math.max(maxX / 3, 1),
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(fmt.format(first.add(Duration(days: v.round()))), style: context.text.labelSmall),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (target != null)
                HorizontalLine(
                  y: target!,
                  color: context.palette.success.withValues(alpha: 0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.colors.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} kg\n${fmt.format(first.add(Duration(days: s.x.round())))}',
                    TextStyle(color: context.colors.onInverseSurface, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: spots.length < 20),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.stats});
  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final goal = stats.goalKcal.toDouble();
    final maxKcal = stats.days.fold<double>(goal, (m, d) => math.max(m, d.macros.kcal));
    // Round gridline step (500 or 1000 kcal) and a top value that lands on it.
    final step = maxKcal > 3500 ? 1000.0 : 500.0;
    final chartMax = ((maxKcal * 1.1) / step).ceil() * step;
    final dense = stats.days.length > 10;
    final fmt = DateFormat(dense ? 'd/M' : 'E');
    final barWidth = dense ? (stats.days.length > 40 ? 3.0 : 6.0) : 18.0;
    final labelEvery = (stats.days.length / 7).ceil();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calories', style: context.text.titleMedium),
          const SizedBox(height: Space.xxs),
          Text(
            'Green = on target · dashed = goal',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.md),
          if (!stats.hasData)
            const InlineEmpty(
              icon: Icons.bar_chart_rounded,
              title: 'No meals logged',
              message: 'Daily totals will show here.',
            )
          else
            SizedBox(
              height: 200,
              child: Semantics(
                label: 'Daily calories bar chart, average ${stats.avg.kcal.round()} calories',
                child: BarChart(
                  duration: motionDuration(context, AppDurations.slow),
                  BarChartData(
                    maxY: chartMax,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: step,
                      getDrawingHorizontalLine: (_) => FlLine(color: context.colors.outlineVariant, strokeWidth: 1),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: goal,
                          color: context.colors.onSurfaceVariant,
                          strokeWidth: 1.2,
                          dashArray: [6, 4],
                        ),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: step,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                              style: context.text.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= stats.days.length || i % labelEvery != 0) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                              child: Text(fmt.format(stats.days[i].date), style: context.text.labelSmall),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => context.colors.inverseSurface,
                        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                          '${formatKcal(rod.toY)} kcal\n${DateFormat('EEE d MMM').format(stats.days[group.x].date)}',
                          TextStyle(color: context.colors.onInverseSurface, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < stats.days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: stats.days[i].macros.kcal,
                              width: barWidth,
                              borderRadius: BorderRadius.circular(barWidth / 2),
                              color: (stats.days[i].macros.kcal - goal).abs() <= goal * 0.1
                                  ? context.palette.success
                                  : stats.days[i].macros.kcal > goal
                                  ? context.palette.warning
                                  : context.palette.carbs,
                              backDrawRodData: BackgroundBarChartRodData(
                                show: !dense,
                                toY: goal,
                                color: context.colors.surfaceContainer,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroTrendCard extends StatelessWidget {
  const _MacroTrendCard({required this.stats});
  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final logged = [
      for (var i = 0; i < stats.days.length; i++)
        if (stats.days[i].logged) (i, stats.days[i]),
    ];

    LineChartBarData line(Color c, double Function(int idx) value) => LineChartBarData(
      spots: [for (final (i, _) in logged) FlSpot(i.toDouble(), value(i))],
      isCurved: true,
      preventCurveOverShooting: true,
      color: c,
      barWidth: 3,
      dotData: FlDotData(show: logged.length < 15),
    );

    Widget legend(Color c, String label, double avg) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ${avg.round()}g avg', style: context.text.labelMedium),
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macro trends', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              legend(p.protein, 'Protein', stats.avg.protein),
              legend(p.carbs, 'Carbs', stats.avg.carbs),
              legend(p.fat, 'Fat', stats.avg.fat),
            ],
          ),
          const SizedBox(height: Space.md),
          if (logged.length < 2)
            const InlineEmpty(
              icon: Icons.show_chart_rounded,
              title: 'Not enough data yet',
              message: 'Log two days to see trends.',
            )
          else
            SizedBox(
              height: 180,
              child: Semantics(
                label:
                    'Macro trend chart. Average protein ${stats.avg.protein.round()} grams, '
                    'carbs ${stats.avg.carbs.round()} grams, fat ${stats.avg.fat.round()} grams',
                child: LineChart(
                  duration: motionDuration(context, AppDurations.slow),
                  LineChartData(
                    minY: 0,
                    minX: 0,
                    maxX: (stats.days.length - 1).toDouble(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: context.colors.outlineVariant, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text('${v.round()}g', style: context.text.labelSmall),
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => context.colors.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${s.y.round()}g',
                              TextStyle(color: s.bar.color, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      line(p.protein, (i) => stats.days[i].macros.protein),
                      line(p.carbs, (i) => stats.days[i].macros.carbs),
                      line(p.fat, (i) => stats.days[i].macros.fat),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A short dashed line, used as the chart key for the goal.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 5, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
