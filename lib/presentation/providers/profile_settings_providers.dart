import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/services/sound_fx.dart';
import '../../core/services/notification_service.dart';
import '../../domain/entities/drink.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/nutrition_calculator.dart';
import 'core_providers.dart';

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => ref.watch(profileRepoProvider).load();

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(profileRepoProvider).save(profile);
  }

  /// Keeps the profile weight in sync with the latest weigh-in and
  /// recalculates targets unless the user set them manually.
  Future<void> syncWeight(double kg) async {
    final p = state;
    if (p == null) return;
    var next = p.copyWith(weightKg: kg);
    if (!p.customTargets) next = next.copyWith(targets: NutritionCalculator.forProfile(next));
    await save(next);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final s = ref.watch(settingsRepoProvider).load();
    Haptics.enabled = s.haptics;
    SoundFx.enabled = s.sounds;
    return s;
  }

  Future<void> _save(AppSettings s) async {
    state = s;
    Haptics.enabled = s.haptics;
    SoundFx.enabled = s.sounds;
    await ref.read(settingsRepoProvider).save(s);
  }

  Future<void> setAiModel(ClaudeModel m) => _save(state.copyWith(aiModel: m));
  Future<void> setThemeMode(ThemeMode mode) => _save(state.copyWith(themeMode: mode));
  Future<void> setReduceMotion(bool v) => _save(state.copyWith(reduceMotion: v));
  Future<void> setHaptics(bool v) => _save(state.copyWith(haptics: v));
  Future<void> setSounds(bool v) => _save(state.copyWith(sounds: v));
  Future<void> setHealthConnected(bool v) => _save(state.copyWith(healthConnected: v));
  Future<void> setCountActivityCalories(bool v) => _save(state.copyWith(countActivityCalories: v));
  Future<void> setWaterGoal(int ml) => _save(state.copyWith(waterGoalMl: ml));
  Future<void> setMochiOutfit(List<String> ids) => _save(state.copyWith(mochiOutfit: ids));
  Future<void> setMochiLevelSeen(int level) => _save(state.copyWith(mochiLevelSeen: level));
  Future<void> saveBottle(SavedBottle b) =>
      _save(state.copyWith(savedBottles: [...state.savedBottles.where((x) => x.id != b.id), b]));
  Future<void> removeBottle(String id) => _save(
    state.copyWith(
      savedBottles: [
        for (final b in state.savedBottles)
          if (b.id != id) b,
      ],
    ),
  );
  Future<void> markCelebrated(String dayKey) => _save(state.copyWith(lastCelebratedDay: dayKey));

  /// Returns false if the OS denied notification permission.
  Future<bool> setMealReminders(bool enabled) async {
    if (enabled && !await NotificationService.instance.requestPermission()) return false;
    await NotificationService.instance.setMealReminders(enabled);
    await _save(state.copyWith(mealReminders: enabled));
    return true;
  }

  Future<bool> setCoachNotifications(bool enabled) async {
    if (enabled && !await NotificationService.instance.requestPermission()) return false;
    await _save(state.copyWith(coachNotifications: enabled));
    return true;
  }

  Future<bool> setWaterReminders(bool enabled) async {
    if (enabled && !await NotificationService.instance.requestPermission()) return false;
    await NotificationService.instance.setWaterReminders(enabled);
    await _save(state.copyWith(waterReminders: enabled));
    return true;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
