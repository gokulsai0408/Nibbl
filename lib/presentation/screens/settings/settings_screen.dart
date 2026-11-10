import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/sound_fx.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/user_profile.dart';
import '../../providers/coach_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/food_providers.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/profile_settings_providers.dart';
import '../../providers/progress_providers.dart';
import '../../providers/social_providers.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/common.dart';
import '../../widgets/model_switch.dart';
import '../../widgets/motion.dart';
import '../../widgets/theme_fade.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  void _reloadAll() {
    ref
      ..invalidate(profileProvider)
      ..invalidate(settingsProvider)
      ..invalidate(logsProvider)
      ..invalidate(dayMetaProvider)
      ..invalidate(foodsProvider)
      ..invalidate(favoritesProvider)
      ..invalidate(templatesProvider)
      ..invalidate(weightsProvider)
      ..invalidate(chatProvider)
      ..invalidate(pantryProvider)
      ..invalidate(savedRecipesProvider)
      ..invalidate(selectedDateProvider);
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } catch (e) {
      if (mounted) showAppSnack(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final service = ref.read(backupServiceProvider);
    try {
      final snapshot = await service.pickBackup();
      if (snapshot == null || !mounted) return;
      final when = DateTime.tryParse(snapshot['exportedAt'] as String? ?? '');
      final ok = await _confirm(
        'Replace all data?',
        'This replaces everything on this device with the backup${when == null ? '' : ' from ${when.friendlyLabel}'}.',
        'Import',
      );
      if (!ok) return;
      setState(() => _busy = true);
      await service.restore(snapshot);
      _reloadAll();
      Haptics.success();
      if (mounted) showAppSnack(context, 'Backup restored');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      'Delete all data?',
      'Your profile, food log, weights and chats will be permanently deleted from this device. Export a backup first if you want to keep them.',
      'Delete everything',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(settingsProvider.notifier).setMealReminders(false);
    await ref.read(settingsProvider.notifier).setWaterReminders(false);
    await ref.read(backupServiceProvider).wipeAll();
    Haptics.warning();
    _reloadAll();
  }

  Future<bool> _confirm(String title, String body, String action, {bool destructive = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.colors.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleReminder(Future<bool> Function(bool) setter, bool value) async {
    Haptics.tap();
    final ok = await setter(value);
    if (!ok && mounted) {
      showAppSnack(context, 'Notifications are blocked. Enable them for Nibbl in system settings.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final weights = ref.watch(weightsProvider);
    final config = ref.watch(appConfigProvider);
    final ai = ref.watch(aiServiceProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final p = context.palette;

    final sections = <Widget>[
      Semantics(header: true, child: Text('Profile', style: context.text.headlineMedium)),
      if (profile != null) _ProfileHero(profile: profile, startWeight: weights.firstOrNull?.kg ?? profile.weightKg),
      if (profile != null) _TargetsCard(targets: profile.targets, custom: profile.customTargets),
      _Group(
        title: 'Appearance',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
            child: SegmentedButton<ThemeMode>(
              // No extra checkmark; labels stay on one line and shrink slightly if needed.
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('System', maxLines: 1, softWrap: false)),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Light', maxLines: 1, softWrap: false)),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Dark', maxLines: 1, softWrap: false)),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) {
                Haptics.tap();
                ThemeFade.change(context, () => notifier.setThemeMode(s.first));
              },
            ),
          ),
          SwitchListTile(
            secondary: const _IconBadge(Icons.animation_rounded, Color(0xFF7C5CFF)),
            title: const Text('Reduce motion'),
            value: settings.reduceMotion,
            onChanged: notifier.setReduceMotion,
          ),
          SwitchListTile(
            secondary: const _IconBadge(Icons.volume_up_rounded, Color(0xFFF2994A)),
            title: const Text('Sound effects'),
            value: settings.sounds,
            onChanged: (v) {
              notifier.setSounds(v);
              if (v) SoundFx.squeak();
            },
          ),
          SwitchListTile(
            secondary: const _IconBadge(Icons.vibration_rounded, Color(0xFF4D7CFE)),
            title: const Text('Haptics'),
            value: settings.haptics,
            onChanged: (v) {
              notifier.setHaptics(v);
              if (v) Haptics.medium();
            },
          ),
        ],
      ),
      _Group(
        title: 'Hydration',
        children: [
          ListTile(
            leading: _IconBadge(Icons.water_drop_rounded, p.water),
            title: const Text('Daily water goal'),
            trailing: Text('${(settings.waterGoalMl / 1000).toStringAsFixed(1)} L', style: context.text.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Slider(
              value: settings.waterGoalMl.toDouble(),
              min: 1000,
              max: 5000,
              divisions: 16,
              label: '${(settings.waterGoalMl / 1000).toStringAsFixed(2)} L',
              semanticFormatterCallback: (v) => '${(v / 1000).toStringAsFixed(2)} litres',
              onChanged: (v) => notifier.setWaterGoal(v.round()),
            ),
          ),
        ],
      ),
      _Group(
        title: 'Smart notifications',
        children: [
          SwitchListTile(
            secondary: _IconBadge(Icons.wb_sunny_rounded, context.colors.tertiary),
            title: const Text('Daily plan & wrap-up'),
            subtitle: const Text('Morning plan, challenge check-ins, evening summary'),
            value: settings.coachNotifications,
            onChanged: (v) => _toggleReminder(notifier.setCoachNotifications, v),
          ),
          SwitchListTile(
            secondary: _IconBadge(Icons.restaurant_rounded, context.colors.primary),
            title: const Text('Meal nudges'),
            subtitle: const Text('Only if a meal isn\'t logged by your usual time, with "log my usual"'),
            value: settings.mealReminders,
            onChanged: (v) => _toggleReminder(notifier.setMealReminders, v),
          ),
          SwitchListTile(
            secondary: _IconBadge(Icons.local_drink_rounded, p.water),
            title: const Text('Water check-ins'),
            subtitle: const Text('Only when you\'re behind pace, with +250 ml buttons'),
            value: settings.waterReminders,
            onChanged: (v) => _toggleReminder(notifier.setWaterReminders, v),
          ),
        ],
      ),
      _Group(
        title: 'Connected apps',
        children: [
          ListTile(
            leading: _IconBadge(Icons.favorite_rounded, settings.healthConnected ? p.success : const Color(0xFF9AA0A6)),
            title: const Text('Health Connect'),
            subtitle: Text(settings.healthConnected ? 'Connected' : 'Steps & workouts'),
            trailing: settings.healthConnected
                ? TextButton(
                    onPressed: () async {
                      final ok = await _confirm(
                        'Disconnect Health Connect?',
                        'Nibbl will stop reading your activity. To fully revoke access, also remove Nibbl in Health Connect settings.',
                        'Disconnect',
                      );
                      if (ok) await notifier.setHealthConnected(false);
                    },
                    child: const Text('Disconnect'),
                  )
                : FilledButton.tonal(
                    onPressed: () => showConnectFitnessSheet(context, ref),
                    child: const Text('Connect'),
                  ),
          ),
          if (settings.healthConnected)
            SwitchListTile(
              secondary: _IconBadge(Icons.local_fire_department_rounded, p.warning),
              title: const Text('Add workout calories to my budget'),
              value: settings.countActivityCalories,
              onChanged: notifier.setCountActivityCalories,
            ),
        ],
      ),
      _Group(
        title: 'Friends',
        children: [
          ListTile(
            leading: const _IconBadge(Icons.people_alt_rounded, Color(0xFFFF6B9A)),
            title: const Text('Friends & posts'),
            subtitle: Consumer(
              builder: (context, ref, _) {
                final me = ref.watch(myProfileProvider).value;
                final n = ref.watch(incomingRequestCountProvider);
                return Text(
                  me == null
                      ? 'Pick a username to connect'
                      : n > 0
                      ? '${me.handle} · $n new request${n == 1 ? '' : 's'}'
                      : me.handle,
                );
              },
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/social'),
          ),
        ],
      ),
      _Group(
        title: 'AI',
        children: [
          ListTile(
            leading: _IconBadge(
              config.hasLiveAi ? Icons.auto_awesome_rounded : Icons.science_rounded,
              config.hasLiveAi ? p.success : context.colors.tertiary,
            ),
            title: Text(config.hasLiveAi ? 'Connected' : 'Demo mode'),
            subtitle: AnimatedSwitcher(
              duration: motionDuration(context, AppDurations.fast),
              // Default layout centres the text; keep it left-aligned like other rows.
              layoutBuilder: (current, previous) =>
                  Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
              child: Text(
                config.hasLiveAi ? ai.displayName : 'Add AI_API_KEY to .env and rebuild to use Claude.',
                key: ValueKey(ai.displayName),
              ),
            ),
          ),
          if (config.provider == AiProvider.anthropic || !config.hasLiveAi) ...[
            const Padding(padding: EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.md), child: ModelPicker()),
          ],
        ],
      ),
      _Group(
        title: 'Library & data',
        children: [
          ListTile(
            leading: _IconBadge(Icons.bookmarks_rounded, context.colors.secondary),
            title: const Text('Saved meals & custom foods'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/foods?tab=3'),
          ),
          ListTile(
            leading: const _IconBadge(Icons.ios_share_rounded, Color(0xFF34A853)),
            title: const Text('Export backup'),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: !_busy,
            onTap: _export,
          ),
          ListTile(
            leading: const _IconBadge(Icons.download_rounded, Color(0xFF4D7CFE)),
            title: const Text('Import backup'),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: !_busy,
            onTap: _import,
          ),
          ListTile(
            leading: _IconBadge(Icons.delete_forever_rounded, context.colors.error),
            title: Text('Delete all data', style: TextStyle(color: context.colors.error)),
            enabled: !_busy,
            onTap: _reset,
          ),
        ],
      ),
      Center(
        child: Text(
          'Nibbl 1.0.0 · Estimates only, not medical advice.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    ];

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: SectionList(
            gap: Space.lg,
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.navClearance),
            children: sections,
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}

/// Avatar, name, goal and weight progress, with a shortcut to edit goals.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.startWeight});
  final UserProfile profile;
  final double startWeight;

  @override
  Widget build(BuildContext context) {
    final pr = profile;
    final initial = pr.name.trim().isEmpty ? pr.goal.emoji : pr.name.trim().characters.first.toUpperCase();
    final toGo = (pr.targetWeightKg - pr.weightKg).abs();
    final span = (startWeight - pr.targetWeightKg).abs();
    final progress = pr.goal == Goal.maintain || span < 0.1 ? 1.0 : (1 - toGo / span).clamp(0.0, 1.0);
    final goalText = pr.goal == Goal.maintain
        ? '${pr.goal.emoji} ${pr.goal.label}'
        : '${pr.goal.emoji} ${pr.goal.label} · ${pr.paceKgPerWeek} kg/week';

    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: context.text.titleLarge),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );

    return AppCard(
      gradient: BrandSurfaces.hero(context.isDark),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: context.palette.heroGradient, shape: BoxShape.circle),
                child: Text(initial, style: context.text.headlineMedium?.copyWith(color: context.palette.onHero)),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pr.name.trim().isEmpty ? 'You' : pr.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall,
                    ),
                    const SizedBox(height: Space.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: context.isDark ? 0.45 : 0.85),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        goalText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              stat('Now', '${pr.weightKg.toStringAsFixed(1)} kg'),
              stat('Target', '${pr.targetWeightKg.toStringAsFixed(1)} kg'),
              stat('BMI', pr.bmi.toStringAsFixed(1)),
            ],
          ),
          if (pr.goal != Goal.maintain) ...[
            const SizedBox(height: Space.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: motionDuration(context, AppDurations.ring),
                curve: AppCurves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: context.colors.primary,
                  backgroundColor: context.colors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              toGo < 0.1 ? 'Target reached 🎉' : '${toGo.toStringAsFixed(1)} kg to go',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Space.md),
          FilledButton.icon(
            onPressed: () => context.push('/goals'),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Edit goals'),
          ),
        ],
      ),
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.targets, required this.custom});
  final NutritionTargets targets;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tile(String label, String value, String unit, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.smAll),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: unit, style: context.text.labelSmall),
                  ],
                ),
              ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Daily targets', style: context.text.titleMedium)),
              Text(
                custom ? 'Custom' : 'Recommended',
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              tile('Calories', formatKcal(targets.calories), '', context.colors.primary),
              const SizedBox(width: Space.xs),
              tile('Protein', '${targets.protein}', 'g', p.protein),
              const SizedBox(width: Space.xs),
              tile('Carbs', '${targets.carbs}', 'g', p.carbs),
              const SizedBox(width: Space.xs),
              tile('Fat', '${targets.fat}', 'g', p.fat),
            ],
          ),
        ],
      ),
    );
  }
}

/// iOS-settings style colored icon square.
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 19, color: Colors.white),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.xs),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 1.1),
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(children: children),
        ),
      ],
    );
  }
}
