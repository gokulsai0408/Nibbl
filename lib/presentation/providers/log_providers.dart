import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_x.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/macros.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/entities/user_profile.dart';
import 'core_providers.dart';
import 'profile_settings_providers.dart';

const _uuid = Uuid();

/// The day being viewed/logged on the home screen.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().dateOnly;

  void select(DateTime day) => state = day.dateOnly;
  void previous() => state = state.subtract(const Duration(days: 1));
  void next() {
    final n = state.add(const Duration(days: 1));
    if (!n.isAfter(DateTime.now().dateOnly)) state = n;
  }

  void today() => state = DateTime.now().dateOnly;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

class LogsNotifier extends Notifier<List<FoodLog>> {
  @override
  List<FoodLog> build() => ref.watch(logRepoProvider).all();

  Future<List<FoodLog>> addFoods(
    List<LoggedFood> foods, {
    required MealType meal,
    required DateTime day,
    required LogSource source,
  }) async {
    final now = DateTime.now();
    final entries = [
      for (var i = 0; i < foods.length; i++)
        FoodLog(
          id: _uuid.v4(),
          dayKey: day.dayKey,
          meal: meal,
          food: foods[i],
          source: source,
          createdAt: now.add(Duration(microseconds: i)),
        ),
    ];
    state = [...state, ...entries];
    await ref.read(logRepoProvider).upsertAll(entries);
    return entries;
  }

  Future<void> update(FoodLog log) async {
    state = [for (final l in state) l.id == log.id ? log : l];
    await ref.read(logRepoProvider).upsert(log);
  }

  Future<void> remove(String id) async {
    state = state.where((l) => l.id != id).toList();
    await ref.read(logRepoProvider).delete(id);
  }

  Future<void> removeAll(Iterable<String> ids) async {
    final set = ids.toSet();
    state = state.where((l) => !set.contains(l.id)).toList();
    for (final id in set) {
      await ref.read(logRepoProvider).delete(id);
    }
  }

  /// Re-inserts previously removed entries (undo).
  Future<void> restore(List<FoodLog> logs) async {
    final ids = logs.map((l) => l.id).toSet();
    state = [...state.where((l) => !ids.contains(l.id)), ...logs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await ref.read(logRepoProvider).upsertAll(logs);
  }
}

final logsProvider = NotifierProvider<LogsNotifier, List<FoodLog>>(LogsNotifier.new);

final logsByDayProvider = Provider<Map<String, List<FoodLog>>>((ref) {
  final map = <String, List<FoodLog>>{};
  for (final l in ref.watch(logsProvider)) {
    (map[l.dayKey] ??= []).add(l);
  }
  return map;
});

class DayMetaNotifier extends Notifier<Map<String, DayMeta>> {
  @override
  Map<String, DayMeta> build() => ref.watch(dayMetaRepoProvider).all();

  DayMeta of(String dayKey) => state[dayKey] ?? DayMeta(dayKey: dayKey);

  Future<void> _save(DayMeta meta) async {
    state = {...state, meta.dayKey: meta};
    await ref.read(dayMetaRepoProvider).save(meta);
  }

  Future<void> addWater(String dayKey, int deltaMl) {
    final m = of(dayKey);
    return _save(m.copyWith(waterMl: (m.waterMl + deltaMl).clamp(0, 10000)));
  }

  Future<void> setNote(String dayKey, String note) => _save(of(dayKey).copyWith(note: note.trim()));
}

final dayMetaProvider = NotifierProvider<DayMetaNotifier, Map<String, DayMeta>>(DayMetaNotifier.new);

/// Everything the dashboard needs for one day.
class DaySummary {
  const DaySummary({
    required this.dayKey,
    required this.logs,
    required this.byMeal,
    required this.totals,
    required this.targets,
    required this.meta,
    required this.waterGoalMl,
  });

  final String dayKey;
  final List<FoodLog> logs;
  final Map<MealType, List<FoodLog>> byMeal;
  final Macros totals;
  final NutritionTargets targets;
  final DayMeta meta;
  final int waterGoalMl;

  double get remainingKcal => targets.calories - totals.kcal;
  double get calorieProgress => targets.calories == 0 ? 0 : totals.kcal / targets.calories;
  bool get isEmpty => logs.isEmpty;
}

const fallbackTargets = NutritionTargets(calories: 2000, protein: 120, carbs: 220, fat: 65);

final daySummaryProvider = Provider.family<DaySummary, String>((ref, dayKey) {
  final logs = ref.watch(logsByDayProvider)[dayKey] ?? const <FoodLog>[];
  final targets = ref.watch(profileProvider.select((p) => p?.targets)) ?? fallbackTargets;
  final meta = ref.watch(dayMetaProvider.select((m) => m[dayKey])) ?? DayMeta(dayKey: dayKey);
  final waterGoal = ref.watch(settingsProvider.select((s) => s.waterGoalMl));
  final byMeal = {for (final m in MealType.values) m: <FoodLog>[]};
  for (final l in logs) {
    byMeal[l.meal]!.add(l);
  }
  return DaySummary(
    dayKey: dayKey,
    logs: logs,
    byMeal: byMeal,
    totals: Macros.sum(logs.map((l) => l.food.macros)),
    targets: targets,
    meta: meta,
    waterGoalMl: waterGoal,
  );
});

final selectedDaySummaryProvider = Provider<DaySummary>((ref) {
  final day = ref.watch(selectedDateProvider);
  return ref.watch(daySummaryProvider(day.dayKey));
});

/// Consecutive days with at least one log, ending today (or yesterday if
/// nothing has been logged yet today, so the streak isn't "lost" at breakfast).
final streakProvider = Provider<int>((ref) {
  final byDay = ref.watch(logsByDayProvider);
  var day = DateTime.now().dateOnly;
  if (!byDay.containsKey(day.dayKey)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (byDay.containsKey(day.dayKey)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
});

/// Distinct recently logged foods, newest first.
final recentFoodsProvider = Provider<List<LoggedFood>>((ref) {
  final logs = ref.watch(logsProvider);
  final seen = <String>{};
  final out = <LoggedFood>[];
  for (final l in logs.reversed) {
    final key = l.food.name.toLowerCase();
    if (seen.add(key)) out.add(l.food);
    if (out.length >= 40) break;
  }
  return out;
});
