import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart' hide WorkoutSummary;

import '../../domain/entities/activity.dart';

enum HealthAvailability { available, notInstalled, needsUpdate, unsupported }

class HealthException implements Exception {
  const HealthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads activity from Health Connect (Android) or Apple Health (iOS).
///
/// Mi Fitness, Google Fit, Samsung Health and most wearables sync into these
/// stores, so Forkcast never needs a Xiaomi login. Read-only.
class HealthService {
  Health? _health;
  bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
  ];

  Future<Health> _client() async {
    final h = _health ??= Health();
    if (!_configured) {
      await h.configure();
      _configured = true;
    }
    return h;
  }

  Future<HealthAvailability> availability() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return HealthAvailability.unsupported;
    if (Platform.isIOS) return HealthAvailability.available;
    final status = await (await _client()).getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HealthAvailability.needsUpdate,
      _ => HealthAvailability.notInstalled,
    };
  }

  /// Opens the Play Store page for Health Connect.
  Future<void> installHealthConnect() async => (await _client()).installHealthConnect();

  /// Shows the system permission screen. Returns true if access was granted.
  Future<bool> connect() async {
    final availability = await this.availability();
    if (availability != HealthAvailability.available) {
      throw HealthException(switch (availability) {
        HealthAvailability.notInstalled => 'Health Connect isn\'t installed yet.',
        HealthAvailability.needsUpdate => 'Health Connect needs an update.',
        _ => 'Health data isn\'t supported on this device.',
      });
    }
    final h = await _client();
    return h.requestAuthorization(
      _types,
      permissions: List.filled(_types.length, HealthDataAccess.READ),
    );
  }

  /// Activity for the calendar day containing [day].
  Future<DayActivity> fetchDay(DateTime day) async {
    final h = await _client();
    final start = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final endOfDay = start.add(const Duration(days: 1));
    final end = endOfDay.isAfter(now) ? now : endOfDay;
    if (!end.isAfter(start)) return DayActivity.empty;

    try {
      final steps = await h.getTotalStepsInInterval(start, end) ?? 0;
      // Already de-duplicated by the plugin.
      final points = await h.getHealthDataFromTypes(
        // STEPS is included only to learn which apps are syncing.
        types: const [
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.WORKOUT,
          HealthDataType.DISTANCE_DELTA,
        ],
        startTime: start,
        endTime: end,
      );

      var activeKcal = 0.0;
      var meters = 0.0;
      final workouts = <WorkoutSummary>[];
      final sourceCounts = <String, int>{};
      DateTime? lastDataAt;
      for (final p in points) {
        final source = appName(p.sourceName);
        sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
        if (lastDataAt == null || p.dateTo.isAfter(lastDataAt)) lastDataAt = p.dateTo;
        final v = p.value;
        if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED && v is NumericHealthValue) {
          activeKcal += v.numericValue.toDouble();
        } else if (p.type == HealthDataType.DISTANCE_DELTA && v is NumericHealthValue) {
          meters += v.numericValue.toDouble();
        } else if (p.type == HealthDataType.WORKOUT && v is WorkoutHealthValue) {
          workouts.add(WorkoutSummary(
            name: _prettyWorkout(v.workoutActivityType),
            start: p.dateFrom,
            minutes: p.dateTo.difference(p.dateFrom).inMinutes,
            kcal: v.totalEnergyBurned,
          ));
        }
      }
      // Some sources only record calories on the workout itself.
      if (activeKcal == 0) {
        activeKcal = workouts.fold<double>(0, (a, w) => a + (w.kcal ?? 0));
      }
      workouts.sort((a, b) => b.start.compareTo(a.start));
      return DayActivity(
        steps: steps,
        activeKcal: activeKcal.round(),
        distanceKm: meters / 1000,
        workouts: workouts,
        sources: (sourceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList(),
        lastDataAt: lastDataAt,
      );
    } catch (e) {
      debugPrint('Health read failed: $e');
      throw const HealthException('Couldn\'t read your activity. Check permissions in Health Connect.');
    }
  }

  /// Friendly name for the app that wrote a reading (Android package name).
  static String appName(String source) {
    const known = {
      'com.mi.health': 'Mi Fitness',
      'com.xiaomi.wearable': 'Mi Fitness',
      'com.xiaomi.hm.health': 'Zepp Life',
      'com.huami.watch.hmwatchmanager': 'Zepp',
      'com.google.android.apps.fitness': 'Google Fit',
      'com.sec.android.app.shealth': 'Samsung Health',
      'com.fitbit.FitbitMobile': 'Fitbit',
      'com.garmin.android.apps.connectmobile': 'Garmin Connect',
      'com.oneplus.health.international': 'OHealth',
      'com.heytap.health.international': 'OHealth',
      'com.google.android.apps.healthdata': 'Health Connect',
      'com.strava': 'Strava',
    };
    if (known.containsKey(source)) return known[source]!;
    if (source.isEmpty) return 'Unknown app';
    if (!source.contains('.')) return source; // Already a display name (iOS).
    final last = source.split('.').last;
    return last.isEmpty ? source : last[0].toUpperCase() + last.substring(1);
  }

  static String _prettyWorkout(HealthWorkoutActivityType t) {
    final words = t.name.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.first == 'other') return 'Workout';
    final s = words.join(' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}
