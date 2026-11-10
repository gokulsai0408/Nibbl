import '../entities/food_log.dart';
import '../entities/macros.dart';

/// What a notification button does. The app performs it when tapped.
enum PlanAction {
  logUsual('log_usual', 'Log my usual'),
  snap('snap', '📷 Snap it'),
  water250('water_250', '+250 ml'),
  water500('water_500', '+500 ml'),
  openChallenges('open_challenges', 'Check in'),
  open('open', 'Open');

  const PlanAction(this.id, this.label);
  final String id;
  final String label;

  static PlanAction? byId(String? id) => values.where((a) => a.id == id).firstOrNull;
}

enum PlanChannel { meals, water, coach }

/// One notification to schedule.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.channel,
    this.actions = const [],
    this.meal,
    this.usual = const [],
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final PlanChannel channel;
  final List<PlanAction> actions;

  /// For meal nudges: which meal and the user's usual foods for it.
  final MealType? meal;
  final List<LoggedFood> usual;
}

/// A meal the user eats often, and when they usually log it.
class UsualMeal {
  const UsualMeal({required this.foods, required this.minuteOfDay});
  final List<LoggedFood> foods;
  final int minuteOfDay;

  double get kcal => Macros.sum(foods.map((f) => f.macros)).kcal;
  String get names => foods.map((f) => f.name).join(', ');
}

/// Everything the planner needs about the user's day.
class DayPlanInput {
  const DayPlanInput({
    required this.now,
    required this.todayLogs,
    required this.kcalGoal,
    required this.proteinGoal,
    required this.waterMl,
    required this.waterGoalMl,
    required this.streak,
    required this.usuals,
    this.challengesToCheckIn = const [],
    this.meals = true,
    this.water = true,
    this.coach = true,
  });

  final DateTime now;
  final List<FoodLog> todayLogs;
  final int kcalGoal;
  final int proteinGoal;
  final int waterMl;
  final int waterGoalMl;

  /// Consecutive logged days up to yesterday (today not yet counted).
  final int streak;
  final Map<MealType, UsualMeal> usuals;
  final List<String> challengesToCheckIn;
  final bool meals;
  final bool water;
  final bool coach;
}

/// Builds today's and tomorrow's notifications from real data. Run it again
/// whenever data changes: every notification only says something true and
/// useful right now (no lunch nudge if lunch is logged, no water ping if
/// you're on pace).
abstract final class DayPlanner {
  /// IDs owned by the planner (cancelled and rebuilt on every run).
  static const firstId = 1000;
  static const lastId = 1199;

  static const _defaultMealMinutes = {
    MealType.breakfast: 8 * 60 + 30,
    MealType.lunch: 13 * 60,
    MealType.dinner: 20 * 60,
  };

  /// Learns usual meals from the last two weeks of logs: a meal (same foods)
  /// eaten on at least two days, and the typical time it's logged.
  static Map<MealType, UsualMeal> learnUsuals(List<FoodLog> recentLogs) {
    final out = <MealType, UsualMeal>{};
    for (final meal in [MealType.breakfast, MealType.lunch, MealType.dinner]) {
      final byDay = <String, List<FoodLog>>{};
      for (final l in recentLogs.where((l) => l.meal == meal)) {
        (byDay[l.dayKey] ??= []).add(l);
      }
      if (byDay.isEmpty) continue;
      // Count identical food sets across days.
      final counts = <String, int>{};
      final latest = <String, List<FoodLog>>{};
      for (final day in byDay.keys.toList()..sort()) {
        final logs = byDay[day]!;
        final key = (logs.map((l) => l.food.name.toLowerCase()).toList()..sort()).join('|');
        counts[key] = (counts[key] ?? 0) + 1;
        latest[key] = logs;
      }
      final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
      final minutes = [for (final l in byDay.values.expand((x) => x)) l.createdAt.hour * 60 + l.createdAt.minute]
        ..sort();
      final typical = minutes.length >= 3 ? minutes[minutes.length ~/ 2] : _defaultMealMinutes[meal]!;
      if (best.value >= 2) {
        out[meal] = UsualMeal(foods: [for (final l in latest[best.key]!) l.food], minuteOfDay: typical);
      } else {
        out[meal] = UsualMeal(foods: const [], minuteOfDay: typical);
      }
    }
    return out;
  }

  static List<PlannedNotification> plan(DayPlanInput i) {
    final out = <PlannedNotification>[];
    final today = DateTime(i.now.year, i.now.month, i.now.day);
    final loggedMeals = {for (final l in i.todayLogs) l.meal};
    final kcal = Macros.sum(i.todayLogs.map((l) => l.food.macros));

    void add(int offset, PlannedNotification n) {
      if (n.at.isAfter(i.now)) out.add(n);
    }

    DateTime at(int dayOffset, int minuteOfDay) => today.add(Duration(days: dayOffset, minutes: minuteOfDay));

    for (final offset in [0, 1]) {
      final base = firstId + offset * 100;
      final isToday = offset == 0;
      final logged = isToday ? loggedMeals : <MealType>{};

      // Morning plan: only on days nothing has been logged yet.
      if (i.coach && (!isToday || i.todayLogs.isEmpty)) {
        final extras = i.challengesToCheckIn.isEmpty
            ? ''
            : ' ${i.challengesToCheckIn.length} challenge check-in${i.challengesToCheckIn.length == 1 ? '' : 's'} today.';
        add(
          offset,
          PlannedNotification(
            id: base,
            at: at(offset, 8 * 60),
            title: 'Good morning ☀️ Here\'s today',
            body:
                '${_k(i.kcalGoal)} kcal · ${i.proteinGoal} g protein · ${(i.waterGoalMl / 1000).toStringAsFixed(1)} L water.$extras',
            channel: PlanChannel.coach,
            actions: const [PlanAction.water250, PlanAction.snap],
          ),
        );
      }

      // Meal nudges: 45 min after your usual time, only if that meal isn't logged.
      if (i.meals) {
        for (final (k, meal) in [MealType.breakfast, MealType.lunch, MealType.dinner].indexed) {
          if (logged.contains(meal)) continue;
          final usual = i.usuals[meal];
          final minute = (usual?.minuteOfDay ?? _defaultMealMinutes[meal]!) + 45;
          final hasUsual = usual != null && usual.foods.isNotEmpty;
          add(
            offset,
            PlannedNotification(
              id: base + 10 + k,
              at: at(offset, minute),
              title: '${meal.label} not logged yet ${meal.emoji}',
              body: hasUsual
                  ? 'Your usual: ${usual.names} · ${_k(usual.kcal)} kcal. One tap to log it.'
                  : 'Snap your plate and Mochi does the maths in seconds.',
              channel: PlanChannel.meals,
              actions: hasUsual ? const [PlanAction.logUsual, PlanAction.snap] : const [PlanAction.snap],
              meal: meal,
              usual: hasUsual ? usual.foods : const [],
            ),
          );
        }
      }

      // Water: check-ins only when you're behind pace.
      if (i.water && i.waterGoalMl > 0) {
        final checks = isToday ? const [11 * 60, 14 * 60, 17 * 60, 19 * 60 + 30] : const [14 * 60, 17 * 60];
        final have = isToday ? i.waterMl : 0;
        for (final (k, minute) in checks.indexed) {
          // Pace: spread the goal evenly from 8:00 to 21:00.
          final expected = (i.waterGoalMl * ((minute - 8 * 60) / (13 * 60))).clamp(0, i.waterGoalMl).round();
          if (have >= expected - 250) continue;
          add(
            offset,
            PlannedNotification(
              id: base + 20 + k,
              at: at(offset, minute),
              title: 'Water check 💧',
              body: '${_l(have)} L so far. Aim for about ${_l(expected)} L by now, so one glass gets you closer.',
              channel: PlanChannel.water,
              actions: const [PlanAction.water250, PlanAction.water500],
            ),
          );
        }
      }

      // Challenges still waiting for today's proof.
      if (i.coach && i.challengesToCheckIn.isNotEmpty) {
        final names = i.challengesToCheckIn.take(2).join(', ');
        add(
          offset,
          PlannedNotification(
            id: base + 30,
            at: at(offset, 19 * 60),
            title: 'Challenge check-in 📸',
            body: i.challengesToCheckIn.length == 1
                ? '$names is waiting for today\'s photo.'
                : '$names${i.challengesToCheckIn.length > 2 ? ' and more' : ''} are waiting for today\'s photo.',
            channel: PlanChannel.coach,
            actions: const [PlanAction.openChallenges],
          ),
        );
      }

      // Streak saver: nothing logged by 20:45 but a streak is on the line.
      final streakAtRisk = isToday ? i.streak : i.streak + (i.todayLogs.isNotEmpty ? 1 : 0);
      if (i.meals && streakAtRisk > 0 && (!isToday || i.todayLogs.isEmpty)) {
        add(
          offset,
          PlannedNotification(
            id: base + 40,
            at: at(offset, 20 * 60 + 45),
            title: '🔥 Keep your $streakAtRisk-day streak',
            body: 'Nothing logged today yet. Log anything before midnight to keep it going.',
            channel: PlanChannel.meals,
            actions: const [PlanAction.snap],
          ),
        );
      }

      // Evening wrap-up (today only, once something is logged).
      if (isToday && i.coach && i.todayLogs.isNotEmpty) {
        add(
          offset,
          PlannedNotification(
            id: base + 50,
            at: at(offset, 21 * 60 + 30),
            title: _wrapTitle(kcal.kcal, i.kcalGoal),
            body:
                '${_k(kcal.kcal)} / ${_k(i.kcalGoal)} kcal · protein ${kcal.protein.round()}/${i.proteinGoal} g · '
                'water ${_l(i.waterMl)}/${_l(i.waterGoalMl)} L. ${_tip(i, kcal)}',
            channel: PlanChannel.coach,
            actions: const [PlanAction.open],
          ),
        );
      }
    }
    return out;
  }

  static String _wrapTitle(double kcal, int goal) {
    if (goal <= 0) return 'Your day in Nibbl';
    final ratio = kcal / goal;
    if (ratio >= 0.9 && ratio <= 1.1) return 'Right on target today 🎯';
    if (ratio < 0.9) return 'Nice, light day 🌙';
    return 'Day wrap-up 🌙';
  }

  /// One small, positive suggestion for tomorrow.
  static String _tip(DayPlanInput i, Macros eaten) {
    if (eaten.protein < i.proteinGoal * 0.8) {
      return 'Tomorrow: add eggs, curd, paneer or dal early in the day for protein.';
    }
    if (i.waterMl < i.waterGoalMl * 0.7) return 'Tomorrow: keep a bottle on your desk from the morning.';
    if (eaten.kcal > i.kcalGoal * 1.1) return 'Tomorrow is a fresh start: a lighter dinner balances it out.';
    return 'Great consistency. Same again tomorrow! 💪';
  }

  static String _k(num v) {
    final s = v.round().toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }

  static String _l(int ml) => (ml / 1000).toStringAsFixed(1);
}
