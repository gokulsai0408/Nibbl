import 'package:flutter/material.dart';

import 'drink.dart';

import 'food_log.dart';
import 'macros.dart';

class WeightEntry {
  const WeightEntry({required this.id, required this.date, required this.kg});

  final String id;
  final DateTime date;
  final double kg;

  Map<String, dynamic> toJson() => {'id': id, 'date': date.toIso8601String(), 'kg': kg};

  factory WeightEntry.fromJson(Map<String, dynamic> j) =>
      WeightEntry(id: j['id'] as String, date: DateTime.parse(j['date'] as String), kg: (j['kg'] as num).toDouble());
}

/// Per-day metadata: water intake and a free-form note.
class DayMeta {
  const DayMeta({required this.dayKey, this.waterMl = 0, this.note = ''});

  final String dayKey;
  final int waterMl;
  final String note;

  DayMeta copyWith({int? waterMl, String? note}) =>
      DayMeta(dayKey: dayKey, waterMl: waterMl ?? this.waterMl, note: note ?? this.note);

  Map<String, dynamic> toJson() => {'dayKey': dayKey, 'waterMl': waterMl, 'note': note};

  factory DayMeta.fromJson(Map<String, dynamic> j) => DayMeta(
    dayKey: j['dayKey'] as String,
    waterMl: (j['waterMl'] as num? ?? 0).round(),
    note: j['note'] as String? ?? '',
  );
}

class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final List<LoggedFood> items;
  final DateTime createdAt;

  Macros get macros => Macros.sum(items.map((i) => i.macros));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'items': items.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MealTemplate.fromJson(Map<String, dynamic> j) => MealTemplate(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '🍱',
    items: (j['items'] as List).map((e) => LoggedFood.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.id, required this.role, required this.text, required this.createdAt});

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    role: ChatRole.values.byName(j['role'] as String),
    text: j['text'] as String,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Which Claude model powers food analysis and the coach.
enum ClaudeModel {
  opus('claude-opus-5-5', 'Opus', 'Smartest, most accurate'),
  haiku('claude-haiku-5-5', 'Haiku', 'Fastest replies');

  const ClaudeModel(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class AppSettings {
  const AppSettings({
    this.aiModel = ClaudeModel.opus,
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.haptics = true,
    this.sounds = true,
    this.healthConnected = false,
    this.countActivityCalories = false,
    this.waterGoalMl = 2500,
    this.waterStepMl = 250,
    this.mealReminders = false,
    this.waterReminders = false,
    this.lastCelebratedDay,
    this.mochiOutfit = const [],
    this.mochiLevelSeen = 1,
    this.savedBottles = const [],
    this.coachNotifications = false,
  });

  final ClaudeModel aiModel;
  final ThemeMode themeMode;
  final bool reduceMotion;
  final bool haptics;
  final bool sounds;

  /// True once the user linked Health Connect / Apple Health (Mi Fitness etc.).
  final bool healthConnected;

  /// Add calories burned (from Health Connect) to the day's calorie budget.
  final bool countActivityCalories;
  final int waterGoalMl;
  final int waterStepMl;
  final bool mealReminders;
  final bool waterReminders;

  /// Day key of the last "goal hit" celebration, so confetti fires once a day.
  final String? lastCelebratedDay;

  /// Ids of the accessories Mochi is wearing (one per slot).
  final List<String> mochiOutfit;

  /// Highest Mochi level the user has been told about (for level-up toasts).
  final int mochiLevelSeen;

  /// Bottles/cups the user saved for quick partial logging.
  final List<SavedBottle> savedBottles;

  /// Morning plan, challenge check-in reminder and evening wrap-up.
  final bool coachNotifications;

  AppSettings copyWith({
    ClaudeModel? aiModel,
    ThemeMode? themeMode,
    bool? reduceMotion,
    bool? haptics,
    bool? sounds,
    bool? healthConnected,
    bool? countActivityCalories,
    int? waterGoalMl,
    int? waterStepMl,
    bool? mealReminders,
    bool? waterReminders,
    String? lastCelebratedDay,
    List<String>? mochiOutfit,
    int? mochiLevelSeen,
    List<SavedBottle>? savedBottles,
    bool? coachNotifications,
  }) => AppSettings(
    aiModel: aiModel ?? this.aiModel,
    themeMode: themeMode ?? this.themeMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    haptics: haptics ?? this.haptics,
    sounds: sounds ?? this.sounds,
    healthConnected: healthConnected ?? this.healthConnected,
    countActivityCalories: countActivityCalories ?? this.countActivityCalories,
    waterGoalMl: waterGoalMl ?? this.waterGoalMl,
    waterStepMl: waterStepMl ?? this.waterStepMl,
    mealReminders: mealReminders ?? this.mealReminders,
    waterReminders: waterReminders ?? this.waterReminders,
    lastCelebratedDay: lastCelebratedDay ?? this.lastCelebratedDay,
    mochiOutfit: mochiOutfit ?? this.mochiOutfit,
    mochiLevelSeen: mochiLevelSeen ?? this.mochiLevelSeen,
    savedBottles: savedBottles ?? this.savedBottles,
    coachNotifications: coachNotifications ?? this.coachNotifications,
  );

  Map<String, dynamic> toJson() => {
    'aiModel': aiModel.name,
    'themeMode': themeMode.name,
    'reduceMotion': reduceMotion,
    'haptics': haptics,
    'sounds': sounds,
    'healthConnected': healthConnected,
    'countActivityCalories': countActivityCalories,
    'waterGoalMl': waterGoalMl,
    'waterStepMl': waterStepMl,
    'mealReminders': mealReminders,
    'waterReminders': waterReminders,
    'lastCelebratedDay': lastCelebratedDay,
    'mochiOutfit': mochiOutfit,
    'mochiLevelSeen': mochiLevelSeen,
    'savedBottles': [for (final b in savedBottles) b.toJson()],
    'coachNotifications': coachNotifications,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    aiModel: ClaudeModel.values.asNameMap()[j['aiModel']] ?? ClaudeModel.opus,
    themeMode: ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system,
    reduceMotion: j['reduceMotion'] as bool? ?? false,
    haptics: j['haptics'] as bool? ?? true,
    sounds: j['sounds'] as bool? ?? true,
    healthConnected: j['healthConnected'] as bool? ?? false,
    countActivityCalories: j['countActivityCalories'] as bool? ?? false,
    waterGoalMl: (j['waterGoalMl'] as num? ?? 2500).round(),
    waterStepMl: (j['waterStepMl'] as num? ?? 250).round(),
    mealReminders: j['mealReminders'] as bool? ?? false,
    waterReminders: j['waterReminders'] as bool? ?? false,
    lastCelebratedDay: j['lastCelebratedDay'] as String?,
    mochiOutfit: [for (final e in (j['mochiOutfit'] as List? ?? const [])) e.toString()],
    mochiLevelSeen: (j['mochiLevelSeen'] as num? ?? 1).round(),
    savedBottles: [
      for (final b in (j['savedBottles'] as List? ?? const []))
        if (b is Map) SavedBottle.fromJson(Map<String, dynamic>.from(b)),
    ],
    coachNotifications: j['coachNotifications'] as bool? ?? false,
  );
}
