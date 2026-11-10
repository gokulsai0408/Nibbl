import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/food_log.dart';
import '../../domain/services/day_planner.dart';

/// A tap on a notification or one of its buttons.
class NotificationTap {
  const NotificationTap({required this.action, this.meal, this.usual = const []});
  final PlanAction action;
  final MealType? meal;
  final List<LoggedFood> usual;
}

/// Schedules the smart daily notifications built by [DayPlanner] and reports
/// taps (including action buttons) back to the app.
///
/// Buttons open the app and the app performs the action. Nothing is written
/// from a background isolate, so local data can't get out of sync.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationTap>.broadcast();
  bool _ready = false;
  NotificationTap? _launchTap;

  /// Taps while the app is running.
  Stream<NotificationTap> get taps => _taps.stream;

  // Fixed daily reminders from older versions; cancelled on every plan.
  static const _legacyIds = [100, 101, 102, 200, 201, 202, 203, 204, 205];

  static const _channels = {
    PlanChannel.meals: (
      'meal_reminders',
      'Meal reminders',
      'Only when a meal isn\'t logged yet',
      Importance.defaultImportance,
    ),
    PlanChannel.water: ('water_reminders', 'Water check-ins', 'Only when you\'re behind on water', Importance.low),
    PlanChannel.coach: (
      'coach_updates',
      'Daily plan & wrap-up',
      'Morning plan, challenge check-ins and evening summary',
      Importance.defaultImportance,
    ),
  };

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (r) {
          final tap = _decode(r);
          if (tap != null) _taps.add(tap);
        },
      );
      // Cold start from a notification or one of its buttons.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final r = launch!.notificationResponse;
        if (r != null) _launchTap = _decode(r);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// The tap that launched the app, if any (returned once).
  NotificationTap? takeLaunchTap() {
    final t = _launchTap;
    _launchTap = null;
    return t;
  }

  NotificationTap? _decode(NotificationResponse r) {
    Map<String, dynamic> payload = const {};
    try {
      if (r.payload != null && r.payload!.isNotEmpty) payload = jsonDecode(r.payload!) as Map<String, dynamic>;
    } catch (_) {}
    final action = PlanAction.byId(r.actionId) ?? PlanAction.byId(payload['tap'] as String?) ?? PlanAction.open;
    return NotificationTap(
      action: action,
      meal: MealType.tryParse(payload['meal'] as String?),
      usual: [
        for (final f in (payload['usual'] as List? ?? const []))
          if (f is Map) LoggedFood.fromJson(Map<String, dynamic>.from(f)),
      ],
    );
  }

  /// Asks the OS for permission. Returns true if granted (or not required).
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return true;
  }

  /// Kept for the settings toggles; the planner does the scheduling now.
  Future<void> setMealReminders(bool enabled) => _cancelLegacy();
  Future<void> setWaterReminders(bool enabled) => _cancelLegacy();

  Future<void> _cancelLegacy() async {
    await init();
    if (!_ready) return;
    for (final id in _legacyIds) {
      await _plugin.cancel(id: id);
    }
  }

  String? _lastPlanKey;

  /// Replaces all planner notifications with [plan].
  Future<void> applyPlan(List<PlannedNotification> plan) async {
    await init();
    if (!_ready) return;
    // Skip work when nothing changed since the last run.
    final key = plan.map((n) => '${n.id}@${n.at.millisecondsSinceEpoch}:${n.body}').join('|');
    if (key == _lastPlanKey) return;
    _lastPlanKey = key;

    for (var id = DayPlanner.firstId; id <= DayPlanner.lastId; id++) {
      if (!plan.any((n) => n.id == id)) await _plugin.cancel(id: id);
    }
    for (final id in _legacyIds) {
      await _plugin.cancel(id: id);
    }
    for (final n in plan) {
      final (channelId, name, description, importance) = _channels[n.channel]!;
      final android = AndroidNotificationDetails(
        channelId,
        name,
        channelDescription: description,
        importance: importance,
        priority: importance == Importance.low ? Priority.low : Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(n.body),
        actions: [
          for (final a in n.actions)
            AndroidNotificationAction(a.id, a.label, showsUserInterface: true, cancelNotification: true),
        ],
      );
      final payload = jsonEncode({
        // Tapping the notification itself (not a button).
        'tap': n.actions.contains(PlanAction.openChallenges)
            ? PlanAction.openChallenges.id
            : n.channel == PlanChannel.meals
            ? PlanAction.snap.id
            : PlanAction.open.id,
        'meal': n.meal?.name,
        'usual': [for (final f in n.usual) f.toJson()],
      });
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.local),
          title: n.title,
          body: n.body,
          payload: payload,
          notificationDetails: NotificationDetails(android: android, iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification ${n.id}: $e');
      }
    }
  }
}
