import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/repositories.dart';
import '../local/hive_store.dart';
import '../seed/food_seed.dart';

class HiveProfileRepository implements ProfileRepository {
  HiveProfileRepository(Box<String> box) : _box = JsonBox(box, UserProfile.fromJson, (p) => p.toJson());
  final JsonBox<UserProfile> _box;
  static const _key = 'me';

  @override
  UserProfile? load() => _box.get(_key);

  @override
  Future<void> save(UserProfile profile) => _box.put(_key, profile);

  @override
  Future<void> clear() => _box.clear();
}

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(Box<String> box) : _box = JsonBox(box, AppSettings.fromJson, (s) => s.toJson());
  final JsonBox<AppSettings> _box;
  static const _key = 'app';

  @override
  AppSettings load() => _box.get(_key) ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) => _box.put(_key, settings);
}

class HiveLogRepository implements LogRepository {
  HiveLogRepository(Box<String> box) : _box = JsonBox(box, FoodLog.fromJson, (l) => l.toJson());
  final JsonBox<FoodLog> _box;

  @override
  List<FoodLog> all() => _box.values()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> upsert(FoodLog log) => _box.put(log.id, log);

  @override
  Future<void> upsertAll(Iterable<FoodLog> logs) => _box.putAll({for (final l in logs) l.id: l});

  @override
  Future<void> delete(String id) => _box.delete(id);
}

class HiveFoodRepository implements FoodRepository {
  HiveFoodRepository(this._raw) : _box = JsonBox(_raw, Food.fromJson, (f) => f.toJson());
  final Box<String> _raw;
  final JsonBox<Food> _box;
  static const _favKey = '__favorites__';

  @override
  List<Food> all() {
    final stored = <Food>[];
    for (final key in _raw.keys) {
      if (key == _favKey) continue;
      final f = _box.get(key as String);
      if (f != null) stored.add(f);
    }
    final storedIds = stored.map((f) => f.id).toSet();
    return [...stored, ...builtInFoods.where((f) => !storedIds.contains(f.id))];
  }

  @override
  Future<void> upsert(Food food) => _box.put(food.id, food);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Set<String> favorites() {
    final raw = _raw.get(_favKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setFavorites(Set<String> ids) => _raw.put(_favKey, jsonEncode(ids.toList()));
}

class HiveWeightRepository implements WeightRepository {
  HiveWeightRepository(Box<String> box) : _box = JsonBox(box, WeightEntry.fromJson, (w) => w.toJson());
  final JsonBox<WeightEntry> _box;

  @override
  List<WeightEntry> all() => _box.values()..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> upsert(WeightEntry entry) => _box.put(entry.id, entry);

  @override
  Future<void> delete(String id) => _box.delete(id);
}

class HiveDayMetaRepository implements DayMetaRepository {
  HiveDayMetaRepository(Box<String> box) : _box = JsonBox(box, DayMeta.fromJson, (d) => d.toJson());
  final JsonBox<DayMeta> _box;

  @override
  Map<String, DayMeta> all() => {for (final d in _box.values()) d.dayKey: d};

  @override
  Future<void> save(DayMeta meta) => _box.put(meta.dayKey, meta);
}

class HiveTemplateRepository implements TemplateRepository {
  HiveTemplateRepository(Box<String> box) : _box = JsonBox(box, MealTemplate.fromJson, (t) => t.toJson());
  final JsonBox<MealTemplate> _box;

  @override
  List<MealTemplate> all() => _box.values()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> upsert(MealTemplate template) => _box.put(template.id, template);

  @override
  Future<void> delete(String id) => _box.delete(id);
}

class HiveChatRepository implements ChatRepository {
  HiveChatRepository(Box<String> box) : _box = JsonBox(box, ChatMessage.fromJson, (m) => m.toJson());
  final JsonBox<ChatMessage> _box;

  @override
  List<ChatMessage> all() => _box.values()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> add(ChatMessage message) => _box.put(message.id, message);

  @override
  Future<void> clear() => _box.clear();
}
