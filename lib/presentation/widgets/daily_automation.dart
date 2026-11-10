import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/router/app_router.dart';
import '../../core/services/haptics.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/date_x.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/services/day_planner.dart';
import '../providers/log_providers.dart';
import '../providers/profile_settings_providers.dart';
import '../providers/social_providers.dart';
import 'common.dart';

/// Everything the planner needs, recomputed whenever the user's data changes.
final dayPlanInputProvider = Provider<DayPlanInput>((ref) {
  final now = DateTime.now();
  final todayKey = now.dayKey;
  final logs = ref.watch(logsProvider);
  final day = ref.watch(daySummaryProvider(todayKey));
  final settings = ref.watch(settingsProvider);
  final streak = ref.watch(streakProvider);
  final cutoff = now.subtract(const Duration(days: 14)).dayKey;
  final recent = [
    for (final l in logs)
      if (l.dayKey.compareTo(cutoff) >= 0 && l.dayKey != todayKey) l,
  ];
  final challenges = ref.watch(challengesProvider).value ?? const [];
  return DayPlanInput(
    now: now,
    todayLogs: day.logs,
    kcalGoal: day.targets.calories,
    proteinGoal: day.targets.protein,
    waterMl: day.meta.waterMl,
    waterGoalMl: day.waterGoalMl,
    // The streak provider counts today once something is logged; the planner wants up to yesterday.
    streak: day.logs.isNotEmpty ? (streak - 1).clamp(0, 9999) : streak,
    usuals: DayPlanner.learnUsuals(recent),
    challengesToCheckIn: [
      for (final c in challenges)
        if (c.joined && c.isActive && !c.checkedToday) c.title,
    ],
    meals: settings.mealReminders,
    water: settings.waterReminders,
    coach: settings.coachNotifications,
  );
});

/// Keeps notifications and the home-screen widget in sync with the day, and
/// carries out taps on their buttons.
class DailyAutomation extends ConsumerStatefulWidget {
  const DailyAutomation({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DailyAutomation> createState() => _DailyAutomationState();
}

class _DailyAutomationState extends ConsumerState<DailyAutomation> with WidgetsBindingObserver {
  Timer? _debounce;
  StreamSubscription<NotificationTap>? _taps;
  StreamSubscription<Uri?>? _widgetTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taps = NotificationService.instance.taps.listen(_handleTap);
    try {
      _widgetTaps = HomeWidget.widgetClicked.listen(_handleUri, onError: (_) {});
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sync();
      final tap = NotificationService.instance.takeLaunchTap();
      if (tap != null) _handleTap(tap);
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (uri != null) _handleUri(uri);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _taps?.cancel();
    _widgetTaps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Times have moved on: re-plan (e.g. drop notifications already past).
    if (state == AppLifecycleState.resumed) ref.invalidate(dayPlanInputProvider);
  }

  void _sync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      final input = ref.read(dayPlanInputProvider);
      await NotificationService.instance.applyPlan(DayPlanner.plan(input));
      await _updateHomeWidget(input);
    });
  }

  Future<void> _updateHomeWidget(DayPlanInput i) async {
    final eaten = i.todayLogs.fold<double>(0, (a, l) => a + l.food.macros.kcal);
    final protein = i.todayLogs.fold<double>(0, (a, l) => a + l.food.macros.protein);
    final left = i.kcalGoal - eaten;
    final now = i.now;
    final logged = {for (final l in i.todayLogs) l.meal};
    final nextMeal = now.hour < 11
        ? MealType.breakfast
        : now.hour < 16
        ? MealType.lunch
        : MealType.dinner;
    final tip = !logged.contains(nextMeal) && now.hour >= 7
        ? '${nextMeal.label} not logged yet. Tap 📷 to snap it.'
        : protein < i.proteinGoal
        ? '${(i.proteinGoal - protein).round()} g protein to go today 💪'
        : 'Protein goal hit. Nice work! 🎉';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final data = <String, String>{
      'headline': 'Today · ${days[now.weekday - 1]} ${now.day}',
      'streak': i.streak + (i.todayLogs.isNotEmpty ? 1 : 0) > 0
          ? '🔥 ${i.streak + (i.todayLogs.isNotEmpty ? 1 : 0)}'
          : '',
      'kcal_value': _fmt(left.abs()),
      'kcal_label': left >= 0 ? 'kcal left' : 'kcal over',
      'kcal_pct': '${i.kcalGoal <= 0 ? 0 : (eaten / i.kcalGoal * 100).round().clamp(0, 100)}',
      'water_text': '💧 ${(i.waterMl / 1000).toStringAsFixed(1)} / ${(i.waterGoalMl / 1000).toStringAsFixed(1)} L',
      'water_pct': '${i.waterGoalMl <= 0 ? 0 : (i.waterMl / i.waterGoalMl * 100).round().clamp(0, 100)}',
      'tip': tip,
    };
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.forkcast.forkcast.NibblWidgetProvider');
    } catch (_) {
      // No widget support (tests, other platforms).
    }
  }

  static String _fmt(num v) {
    final s = v.round().toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }

  // ------------------------------------------------------------ actions

  void _addWater(int ml) {
    final water = ref.read(dayMetaProvider.notifier);
    final key = DateTime.now().dayKey;
    water.addWater(key, ml);
    Haptics.light();
    if (mounted) {
      showAppSnack(context, 'Added $ml ml of water 💧', onUndo: () => water.addWater(key, -ml));
    }
  }

  Future<void> _logUsual(MealType meal, List<LoggedFood> foods) async {
    if (foods.isEmpty) return;
    final logs = ref.read(logsProvider.notifier);
    final added = await logs.addFoods(foods, meal: meal, day: DateTime.now().dateOnly, source: LogSource.template);
    Haptics.success();
    if (mounted) {
      showAppSnack(
        context,
        'Logged your usual ${meal.label.toLowerCase()} ${meal.emoji}',
        onUndo: () => logs.removeAll(added.map((l) => l.id)),
      );
    }
  }

  void _handleTap(NotificationTap tap) {
    final router = ref.read(routerProvider);
    switch (tap.action) {
      case PlanAction.water250:
        _addWater(250);
      case PlanAction.water500:
        _addWater(500);
      case PlanAction.logUsual:
        if (tap.meal != null) _logUsual(tap.meal!, tap.usual);
      case PlanAction.snap:
        router.push('/log/photo${tap.meal == null ? '' : '?meal=${tap.meal!.name}'}');
      case PlanAction.openChallenges:
        router.push('/social');
      case PlanAction.open:
        break;
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.scheme != 'nibbl') return;
    final router = ref.read(routerProvider);
    switch (uri.host) {
      case 'water':
        _addWater(int.tryParse(uri.queryParameters['ml'] ?? '') ?? 250);
      case 'log':
        router.push('/log/${uri.pathSegments.firstOrNull ?? 'photo'}');
      default:
        router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dayPlanInputProvider, (_, _) => _sync());
    return widget.child;
  }
}
