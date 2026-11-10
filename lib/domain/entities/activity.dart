/// One workout session (e.g. synced from Mi Fitness via Health Connect).
class WorkoutSummary {
  const WorkoutSummary({required this.name, required this.start, required this.minutes, this.kcal});

  final String name;
  final DateTime start;
  final int minutes;
  final int? kcal;
}

/// A day's activity read from the phone's health store.
class DayActivity {
  const DayActivity({
    required this.steps,
    required this.activeKcal,
    required this.distanceKm,
    required this.workouts,
    this.sources = const [],
    this.lastDataAt,
  });

  static const empty = DayActivity(steps: 0, activeKcal: 0, distanceKm: 0, workouts: []);

  /// Apps that wrote today's data (e.g. "Mi Fitness"), most data first.
  final List<String> sources;

  /// End time of the most recent reading - i.e. when data last arrived.
  final DateTime? lastDataAt;

  final int steps;
  final int activeKcal;
  final double distanceKm;
  final List<WorkoutSummary> workouts;

  int get workoutMinutes => workouts.fold(0, (a, w) => a + w.minutes);
  bool get isEmpty => steps == 0 && activeKcal == 0 && workouts.isEmpty;

  /// One-line summary for the coach.
  String describe() {
    final parts = <String>['$steps steps', '$activeKcal kcal burned (active)'];
    if (distanceKm > 0) parts.add('${distanceKm.toStringAsFixed(1)} km');
    if (workouts.isEmpty) {
      parts.add('no workouts');
    } else {
      parts.add(
        'workouts: ${workouts.map((w) => '${w.name} ${w.minutes} min${w.kcal != null ? ' (${w.kcal} kcal)' : ''}').join(', ')}',
      );
    }
    return parts.join(', ');
  }
}
