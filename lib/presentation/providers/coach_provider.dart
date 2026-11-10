import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_x.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/macros.dart';
import '../../domain/entities/tracking.dart';
import 'activity_providers.dart';
import 'core_providers.dart';
import 'kitchen_providers.dart';
import 'log_providers.dart';
import 'profile_settings_providers.dart';
import 'progress_providers.dart';

const _uuid = Uuid();

class ChatState {
  const ChatState({this.messages = const [], this.isTyping = false, this.error});

  final List<ChatMessage> messages;
  final bool isTyping;
  final String? error;

  ChatState copyWith({List<ChatMessage>? messages, bool? isTyping, String? error, bool clearError = false}) =>
      ChatState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => ChatState(messages: ref.watch(chatRepoProvider).all());

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isTyping) return;
    final msg = ChatMessage(id: _uuid.v4(), role: ChatRole.user, text: trimmed, createdAt: DateTime.now());
    state = state.copyWith(messages: [...state.messages, msg], clearError: true);
    await ref.read(chatRepoProvider).add(msg);
    await _respond();
  }

  /// Retries the last failed request.
  Future<void> retry() => _respond();

  Future<void> _respond() async {
    state = state.copyWith(isTyping: true, clearError: true);
    try {
      final reply = await ref.read(aiServiceProvider).coachReply(history: state.messages, context: buildCoachContext());
      final msg = ChatMessage(id: _uuid.v4(), role: ChatRole.assistant, text: reply.trim(), createdAt: DateTime.now());
      state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
      await ref.read(chatRepoProvider).add(msg);
    } catch (e) {
      state = state.copyWith(isTyping: false, error: e.toString());
    }
  }

  Future<void> clear() async {
    state = const ChatState();
    await ref.read(chatRepoProvider).clear();
  }

  /// Plain-text summary of the user's data for the model's system prompt.
  String buildCoachContext() {
    final profile = ref.read(profileProvider);
    final today = ref.read(daySummaryProvider(DateTime.now().dayKey));
    final byDay = ref.read(logsByDayProvider);
    final last7 = [
      for (var i = 0; i < 7; i++) byDay[DateTime.now().subtract(Duration(days: i)).dayKey],
    ].whereType<List<FoodLog>>().where((l) => l.isNotEmpty).toList();
    final weekAvg = last7.isEmpty
        ? Macros.zero
        : Macros.sum(last7.map((day) => Macros.sum(day.map((l) => l.food.macros)))).scale(1 / last7.length);
    final weights = ref.read(weightsProvider);
    final recent = ref.read(recentFoodsProvider).take(10).map((f) => f.name).join(', ');
    final t = today.targets;
    final eaten = today.totals;
    // Workout calories count toward the budget only if the user opted in.
    final burnedToday = ref.read(activityProvider(DateTime.now().dayKey)).value?.activeKcal ?? 0;
    final bonus = ref.read(settingsProvider).countActivityCalories ? burnedToday : 0;
    final b = StringBuffer()
      ..writeln('Date: ${DateTime.now().toIso8601String().substring(0, 10)}, local time ${DateTime.now().hour}:00');
    if (profile != null) {
      b
        ..writeln(
          'Goal: ${profile.goal.label} (target ${profile.targetWeightKg.toStringAsFixed(1)} kg, pace ${profile.paceKgPerWeek} kg/week)',
        )
        ..writeln(
          'Profile: ${profile.sex.label}, ${profile.age} y, ${profile.heightCm.round()} cm, ${profile.weightKg.toStringAsFixed(1)} kg, ${profile.activity.label}',
        );
    }
    b
      ..writeln('Daily calorie target: ${t.calories}')
      ..writeln('Macro targets: protein ${t.protein} g, carbs ${t.carbs} g, fat ${t.fat} g')
      ..writeln(
        'Eaten today: ${eaten.kcal.round()} kcal, protein ${eaten.protein.round()} g, carbs ${eaten.carbs.round()} g, fat ${eaten.fat.round()} g',
      )
      ..writeln('Calories remaining today: ${(t.calories + bonus - eaten.kcal).round()}')
      ..writeln('Protein remaining today: ${(t.protein - eaten.protein).round()}')
      ..writeln('Water today: ${today.meta.waterMl} ml of ${today.waterGoalMl} ml')
      ..writeln(
        'Foods logged today: ${today.logs.map((l) => '${l.meal.label}: ${l.food.name}').join('; ').ifEmpty('nothing yet')}',
      );
    if (last7.isNotEmpty) {
      b
        ..writeln('7-day average calories: ${weekAvg.kcal.round()}')
        ..writeln('7-day average protein: ${weekAvg.protein.round()} g')
        ..writeln('Days logged in last 7: ${last7.length}');
    }
    if (weights.length >= 2) {
      b.writeln(
        'Weight trend: ${weights.first.kg} kg → ${weights.last.kg} kg over ${weights.last.date.difference(weights.first.date).inDays} days',
      );
    }
    final activity = ref.read(activityProvider(DateTime.now().dayKey)).value;
    if (activity != null) b.writeln('Activity today (from fitness tracker): ${activity.describe()}');
    if (recent.isNotEmpty) b.writeln('Frequently/recently eaten: $recent');
    // Mochi remembers the kitchen so ideas use what's actually at home.
    final pantry = ref.read(pantryProvider);
    b.writeln(
      pantry.isEmpty
          ? 'Kitchen: not filled in yet (they can add ingredients in My kitchen).'
          : 'In their kitchen right now: ${pantry.map((p) => p.forPrompt).join(', ')}',
    );
    final saved = ref.read(savedRecipesProvider);
    if (saved.isNotEmpty) {
      b.writeln(
        'Saved recipes: ${saved.take(8).map((r) => '${r.title} (${r.perServing.kcal.round()} kcal)').join('; ')}',
      );
    }
    return b.toString();
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
