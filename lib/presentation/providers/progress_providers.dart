import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_x.dart';
import '../../domain/entities/macros.dart';
import '../../domain/entities/tracking.dart';
import 'core_providers.dart';
import 'log_providers.dart';
import 'profile_settings_providers.dart';

const _uuid = Uuid();

class WeightsNotifier extends Notifier<List<WeightEntry>> {
  @override
  List<WeightEntry> build() => ref.watch(weightRepoProvider).all();

  /// One entry per day; logging again on the same day replaces it.
  Future<void> log(double kg, {DateTime? date}) async {
    final d = (date ?? DateTime.now());
    final existing = state.where((w) => w.date.isSameDay(d)).firstOrNull;
    final entry = WeightEntry(id: existing?.id ?? _uuid.v4(), date: d, kg: kg);
    state = [...state.where((w) => w.id != entry.id), entry]..sort((a, b) => a.date.compareTo(b.date));
    await ref.read(weightRepoProvider).upsert(entry);
    if (state.last.id == entry.id) await ref.read(profileProvider.notifier).syncWeight(kg);
  }

  Future<void> remove(String id) async {
    state = state.where((w) => w.id != id).toList();
    await ref.read(weightRepoProvider).delete(id);
  }
}

final weightsProvider = NotifierProvider<WeightsNotifier, List<WeightEntry>>(WeightsNotifier.new);

enum ProgressRange {
  week(7, '7D'),
  month(30, '30D'),
  quarter(90, '90D');

  const ProgressRange(this.days, this.label);
  final int days;
  final String label;
}

class ProgressRangeNotifier extends Notifier<ProgressRange> {
  @override
  ProgressRange build() => ProgressRange.week;
  void set(ProgressRange r) => state = r;
}

final progressRangeProvider = NotifierProvider<ProgressRangeNotifier, ProgressRange>(ProgressRangeNotifier.new);

class DayPoint {
  const DayPoint(this.date, this.macros, this.logged);
  final DateTime date;
  final Macros macros;
  final bool logged;
}

class ProgressStats {
  const ProgressStats({
    required this.days,
    required this.avg,
    required this.daysLogged,
    required this.goalKcal,
    required this.goalProtein,
    required this.daysOnTarget,
  });

  final List<DayPoint> days;

  /// Average over logged days only.
  final Macros avg;
  final int daysLogged;
  final int goalKcal;
  final int goalProtein;
  final int daysOnTarget;

  bool get hasData => daysLogged > 0;
}

final progressStatsProvider = Provider<ProgressStats>((ref) {
  final range = ref.watch(progressRangeProvider);
  final byDay = ref.watch(logsByDayProvider);
  final targets = ref.watch(profileProvider.select((p) => p?.targets)) ?? fallbackTargets;
  final today = DateTime.now().dateOnly;

  final days = <DayPoint>[];
  for (var i = range.days - 1; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final logs = byDay[d.dayKey];
    days.add(DayPoint(d, Macros.sum((logs ?? const []).map((l) => l.food.macros)), logs != null && logs.isNotEmpty));
  }
  final logged = days.where((d) => d.logged).toList();
  final avg = logged.isEmpty ? Macros.zero : Macros.sum(logged.map((d) => d.macros)).scale(1 / logged.length);
  final onTarget = logged.where((d) => (d.macros.kcal - targets.calories).abs() <= targets.calories * 0.1).length;

  return ProgressStats(
    days: days,
    avg: avg,
    daysLogged: logged.length,
    goalKcal: targets.calories,
    goalProtein: targets.protein,
    daysOnTarget: onTarget,
  );
});
