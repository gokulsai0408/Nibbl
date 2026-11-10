import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/domain/entities/food_log.dart';
import 'package:forkcast/domain/entities/macros.dart';
import 'package:forkcast/domain/services/day_planner.dart';

LoggedFood _food(String name, double kcal, {double protein = 10}) => LoggedFood(
      name: name,
      emoji: '🍽️',
      servingLabel: '1 serving',
      servingGrams: 100,
      base: Macros(kcal: kcal, protein: protein, carbs: 30, fat: 10),
    );

FoodLog _log(String day, MealType meal, LoggedFood f, {int hour = 9, int minute = 0}) {
  final d = DateTime.parse(day);
  return FoodLog(
    id: '$day-${meal.name}-${f.name}',
    dayKey: day,
    meal: meal,
    food: f,
    source: LogSource.text,
    createdAt: DateTime(d.year, d.month, d.day, hour, minute),
  );
}

DayPlanInput _input({
  required DateTime now,
  List<FoodLog> today = const [],
  int water = 0,
  int streak = 5,
  Map<MealType, UsualMeal> usuals = const {},
  List<String> challenges = const [],
}) =>
    DayPlanInput(
      now: now,
      todayLogs: today,
      kcalGoal: 2000,
      proteinGoal: 120,
      waterMl: water,
      waterGoalMl: 2600,
      streak: streak,
      usuals: usuals,
      challengesToCheckIn: challenges,
    );

void main() {
  final morning = DateTime(2026, 11, 10, 7, 0);

  test('learns a usual breakfast eaten on 2+ days, with its typical time', () {
    final poha = _food('Poha', 280);
    final chai = _food('Chai', 90);
    final logs = [
      _log('2026-11-07', MealType.breakfast, poha, hour: 8, minute: 40),
      _log('2026-11-07', MealType.breakfast, chai, hour: 8, minute: 41),
      _log('2026-11-08', MealType.breakfast, poha, hour: 9, minute: 5),
      _log('2026-11-08', MealType.breakfast, chai, hour: 9, minute: 6),
      _log('2026-11-09', MealType.breakfast, _food('Eggs', 150), hour: 8, minute: 50),
    ];
    final usual = DayPlanner.learnUsuals(logs)[MealType.breakfast]!;
    expect(usual.names, contains('Poha'));
    expect(usual.foods, hasLength(2));
    expect(usual.minuteOfDay, inInclusiveRange(8 * 60 + 40, 9 * 60 + 6));
  });

  test('meal nudge offers "log my usual", and disappears once that meal is logged', () {
    final usual = {MealType.lunch: UsualMeal(foods: [_food('Dal rice', 520)], minuteOfDay: 13 * 60)};
    var plan = DayPlanner.plan(_input(now: morning, usuals: usual));
    final lunch = plan.firstWhere((n) => n.meal == MealType.lunch && n.at.day == 10);
    expect(lunch.at, DateTime(2026, 11, 10, 13, 45));
    expect(lunch.actions, contains(PlanAction.logUsual));
    expect(lunch.body, contains('Dal rice'));
    expect(lunch.usual, hasLength(1));

    plan = DayPlanner.plan(
      _input(now: morning, usuals: usual, today: [_log('2026-11-10', MealType.lunch, _food('Salad', 300))]),
    );
    expect(plan.where((n) => n.meal == MealType.lunch && n.at.day == 10), isEmpty);
  });

  test('water check-ins only when behind pace', () {
    final now = DateTime(2026, 11, 10, 10, 0);
    final behind = DayPlanner.plan(_input(now: now, water: 0)).where((n) => n.channel == PlanChannel.water && n.at.day == 10);
    expect(behind, isNotEmpty);
    expect(behind.first.actions, contains(PlanAction.water250));
    final ahead = DayPlanner.plan(_input(now: now, water: 2600)).where((n) => n.channel == PlanChannel.water && n.at.day == 10);
    expect(ahead, isEmpty);
  });

  test('streak saver only when nothing is logged today', () {
    final evening = DateTime(2026, 11, 10, 19, 0);
    final empty = DayPlanner.plan(_input(now: evening, streak: 12));
    expect(empty.any((n) => n.title.contains('12-day streak') && n.at.day == 10), isTrue);
    final logged = DayPlanner.plan(
      _input(now: evening, streak: 12, today: [_log('2026-11-10', MealType.lunch, _food('Roti', 200))]),
    );
    expect(logged.any((n) => n.title.contains('streak') && n.at.day == 10), isFalse);
  });

  test('evening wrap-up summarises the day with a positive tip', () {
    final plan = DayPlanner.plan(
      _input(
        now: DateTime(2026, 11, 10, 18, 0),
        water: 2000,
        today: [_log('2026-11-10', MealType.lunch, _food('Thali', 1900, protein: 60))],
      ),
    );
    final wrap = plan.firstWhere((n) => n.at == DateTime(2026, 11, 10, 21, 30));
    expect(wrap.title, contains('target'));
    expect(wrap.body, contains('1,900 / 2,000 kcal'));
    expect(wrap.body, contains('protein'));
  });

  test('challenge reminder lists challenges still waiting for a photo', () {
    final plan = DayPlanner.plan(_input(now: morning, challenges: ['Move every day']));
    final c = plan.firstWhere((n) => n.actions.contains(PlanAction.openChallenges) && n.at.day == 10);
    expect(c.body, contains('Move every day'));
  });

  test('never schedules anything in the past, and respects toggles', () {
    final late = DateTime(2026, 11, 10, 22, 0);
    final plan = DayPlanner.plan(_input(now: late));
    expect(plan.every((n) => n.at.isAfter(late)), isTrue);
    expect(plan.every((n) => n.id >= DayPlanner.firstId && n.id <= DayPlanner.lastId), isTrue);
    expect(plan.map((n) => n.id).toSet().length, plan.length, reason: 'ids must be unique');

    final off = DayPlanInput(
      now: DateTime(2026, 11, 10, 7),
      todayLogs: [],
      kcalGoal: 2000,
      proteinGoal: 120,
      waterMl: 0,
      waterGoalMl: 2500,
      streak: 3,
      usuals: {},
      meals: false,
      water: false,
      coach: false,
    );
    expect(DayPlanner.plan(off), isEmpty);
  });
}
