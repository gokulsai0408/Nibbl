import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_x.dart';
import '../../data/health/health_service.dart';
import '../../domain/entities/activity.dart';
import 'profile_settings_providers.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

/// Activity for a day (keyed `yyyy-MM-dd`). Null when health data isn't linked.
final activityProvider = FutureProvider.family<DayActivity?, String>((ref, dayKey) async {
  final connected = ref.watch(settingsProvider.select((s) => s.healthConnected));
  if (!connected) return null;
  return ref.read(healthServiceProvider).fetchDay(parseDayKey(dayKey));
});

/// Last 7 days of activity, oldest first. Null when health data isn't linked.
final weekActivityProvider = FutureProvider<List<(DateTime, DayActivity)>?>((ref) async {
  final connected = ref.watch(settingsProvider.select((s) => s.healthConnected));
  if (!connected) return null;
  final health = ref.read(healthServiceProvider);
  final today = DateTime.now().dateOnly;
  final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  final results = await Future.wait(days.map(health.fetchDay));
  return [for (var i = 0; i < days.length; i++) (days[i], results[i])];
});
