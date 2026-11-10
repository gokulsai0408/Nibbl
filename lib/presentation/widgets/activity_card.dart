import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/tokens.dart';
import '../../data/health/health_service.dart';
import '../../domain/entities/activity.dart';
import '../providers/activity_providers.dart';
import '../providers/profile_settings_providers.dart';
import 'common.dart';
import 'count_up_text.dart';

/// Steps, calories burned and workouts from Health Connect.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.dayKey});
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(settingsProvider.select((s) => s.healthConnected));
    final activity = ref.watch(activityProvider(dayKey));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.watch_rounded, color: context.colors.primary),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text('Activity', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              ),
              if (connected)
                IconButton(
                  tooltip: 'Refresh activity',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Haptics.tap();
                    ref.invalidate(activityProvider(dayKey));
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (!connected)
            _ConnectPrompt(onConnect: () => showConnectFitnessSheet(context, ref))
          else
            activity.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.md),
                child: Center(
                  child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              ),
              error: (e, _) => Row(
                children: [
                  Expanded(
                    child: InlineEmpty(
                      icon: Icons.sync_problem_rounded,
                      title: 'Couldn\'t sync',
                      message: e.toString(),
                    ),
                  ),
                  TextButton(onPressed: () => ref.invalidate(activityProvider(dayKey)), child: const Text('Retry')),
                ],
              ),
              data: (a) => _ActivityStats(activity: a ?? DayActivity.empty),
            ),
        ],
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: InlineEmpty(
            icon: Icons.link_rounded,
            title: 'Link Health Connect',
            message: 'See steps and workouts here.',
          ),
        ),
        const SizedBox(width: Space.sm),
        FilledButton.tonal(onPressed: onConnect, child: const Text('Connect')),
      ],
    );
  }
}

class _ActivityStats extends StatelessWidget {
  const _ActivityStats({required this.activity});
  final DayActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final time = DateFormat.jm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Stat(icon: Icons.directions_walk_rounded, value: a.steps, label: 'steps', color: context.palette.water),
            _Stat(
              icon: Icons.local_fire_department_rounded,
              value: a.activeKcal,
              label: 'kcal burned',
              color: context.palette.warning,
            ),
            _Stat(
              icon: Icons.timer_rounded,
              value: a.workoutMinutes,
              label: 'workout min',
              color: context.palette.success,
            ),
          ],
        ),
        for (final w in a.workouts.take(3)) ...[
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: Radii.smAll,
                ),
                child: Icon(Icons.fitness_center_rounded, size: 18, color: context.colors.primary),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  '${w.name} · ${w.minutes} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
              ),
              Text(
                w.kcal != null ? '${w.kcal} kcal' : time.format(w.start),
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
        const SizedBox(height: Space.md),
        _SyncStatus(activity: a),
      ],
    );
  }
}

/// Shows where the data comes from and how fresh it is.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.activity});
  final DayActivity activity;

  @override
  Widget build(BuildContext context) {
    final sources = activity.sources;
    final last = activity.lastDataAt;
    final when = last == null ? '' : ' · ${DateFormat.jm().format(last)}';

    final (IconData icon, Color color, String text) = sources.isNotEmpty
        ? (
            Icons.check_circle_rounded,
            context.palette.success,
            'Synced via Health Connect$when\nFrom ${sources.join(', ')}',
          )
        : (
            Icons.sync_problem_rounded,
            context.palette.warning,
            'Connected, but no data yet. Make sure your fitness app (like Mi Fitness) shares to Health Connect.',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: Radii.smAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: Space.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpText(value: value, style: context.text.titleLarge),
            ),
            Text(
              label,
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

/// Step-by-step sheet to link Health Connect.
Future<void> showConnectFitnessSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _ConnectSheet(),
  );
}

class _ConnectSheet extends ConsumerStatefulWidget {
  const _ConnectSheet();

  @override
  ConsumerState<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends ConsumerState<_ConnectSheet> {
  bool _busy = false;
  bool _needsInstall = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final health = ref.read(healthServiceProvider);
    try {
      final availability = await health.availability();
      if (availability == HealthAvailability.notInstalled || availability == HealthAvailability.needsUpdate) {
        setState(() {
          _needsInstall = true;
          _busy = false;
        });
        return;
      }
      final granted = await health.connect();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _busy = false;
          _error = 'Permission wasn\'t granted. You can try again any time.';
        });
        return;
      }
      await ref.read(settingsProvider.notifier).setHealthConnected(true);
      ref.invalidate(activityProvider);
      await Haptics.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Connected! Your activity now shows on Today.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
            child: Text('$n', style: context.text.labelLarge?.copyWith(color: context.colors.onPrimary)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Link Health Connect', style: context.text.headlineSmall),
          const SizedBox(height: Space.xxs),
          Text(
            'Fitness apps like Mi Fitness share data here. Nibbl only reads it.',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.lg),
          step(1, 'In your fitness app (like Mi Fitness), turn on Health Connect sync.'),
          step(2, 'Tap Connect and allow steps, calories and exercise.'),
          if (_error != null) ...[
            Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
            const SizedBox(height: Space.sm),
          ],
          if (_needsInstall) ...[
            Text(
              'Health Connect is needed first. Install or update it, then come back.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: () => ref.read(healthServiceProvider).installHealthConnect(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Get Health Connect'),
            ),
            const SizedBox(height: Space.sm),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.link_rounded),
            label: Text(_needsInstall ? 'I\'ve installed it, connect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}
