import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_x.dart';
import '../../domain/entities/mochi.dart';
import 'log_providers.dart';
import 'profile_settings_providers.dart';

/// Mochi's XP and level, derived from the user's history (nothing extra is
/// stored, so it survives backups and can never drift out of sync).
final mochiProgressProvider = Provider<MochiProgress>((ref) {
  final byDay = ref.watch(logsByDayProvider);
  final meta = ref.watch(dayMetaProvider);
  final target = ref.watch(profileProvider.select((p) => p?.targets.calories)) ?? fallbackTargets.calories;
  final waterGoal = ref.watch(settingsProvider.select((s) => s.waterGoalMl));
  final today = DateTime.now().dayKey;

  var xp = 0;
  var goalDays = 0;
  var waterDays = 0;
  for (final MapEntry(key: day, value: logs) in byDay.entries) {
    if (logs.isEmpty) continue;
    xp += 10 + 2 * (logs.length > 5 ? 5 : logs.length);
    // Calorie goal only counts once the day is over.
    if (day != today && target > 0) {
      final kcal = logs.fold<double>(0, (a, l) => a + l.food.macros.kcal);
      if ((kcal - target).abs() <= target * 0.1) {
        xp += 15;
        goalDays++;
      }
    }
  }
  for (final m in meta.values) {
    if (waterGoal > 0 && m.waterMl >= waterGoal) {
      xp += 5;
      waterDays++;
    }
  }

  // Streak bonus: +30 for every full 7-day run of consecutive logging days.
  final days = byDay.keys.where((k) => byDay[k]!.isNotEmpty).toList()..sort();
  var run = 0;
  DateTime? prev;
  for (final k in days) {
    final d = DateTime.tryParse(k);
    if (d == null) continue;
    run = (prev != null && (d.difference(prev).inHours / 24).round() == 1) ? run + 1 : 1;
    if (run % 7 == 0) xp += 30;
    prev = d;
  }

  return MochiProgress.fromXp(xp, daysLogged: days.length, goalDays: goalDays, waterDays: waterDays);
});

/// Accessories Mochi is wearing, ignoring anything not unlocked (e.g. after
/// deleting data).
final mochiOutfitProvider = Provider<Set<MochiItem>>((ref) {
  final ids = ref.watch(settingsProvider.select((s) => s.mochiOutfit));
  final level = ref.watch(mochiProgressProvider.select((p) => p.level));
  return {
    for (final id in ids)
      if (MochiItem.byName(id) case final item? when level >= item.unlockLevel) item,
  };
});

/// Toggle an accessory on, replacing anything else in the same slot.
Future<void> toggleMochiItem(WidgetRef ref, MochiItem item) {
  final current = ref.read(mochiOutfitProvider);
  final next = current.contains(item)
      ? current.where((i) => i != item)
      : [...current.where((i) => i.slot != item.slot), item];
  return ref.read(settingsProvider.notifier).setMochiOutfit([for (final i in next) i.name]);
}
