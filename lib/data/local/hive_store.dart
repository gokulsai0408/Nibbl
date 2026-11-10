import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// All persistent data lives in Hive boxes of JSON strings. This keeps the
/// schema flexible, avoids code generation, and makes export/import trivial.
abstract final class HiveStore {
  static const profile = 'profile';
  static const settings = 'settings';
  static const logs = 'logs';
  static const foods = 'foods';
  static const weights = 'weights';
  static const dayMeta = 'day_meta';
  static const templates = 'templates';
  static const chat = 'chat';
  static const pantry = 'pantry';
  static const recipes = 'recipes';

  static const allBoxes = [profile, settings, logs, foods, weights, dayMeta, templates, chat, pantry, recipes];

  static Future<void> init() async {
    await Hive.initFlutter('forkcast');
    for (final name in allBoxes) {
      await Hive.openBox<String>(name);
    }
  }

  static Box<String> box(String name) => Hive.box<String>(name);
}

/// Typed JSON view over a `Box<String>`.
class JsonBox<T> {
  JsonBox(this.box, this.fromJson, this.toJson);

  final Box<String> box;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  List<T> values() {
    final out = <T>[];
    for (final raw in box.values) {
      try {
        out.add(fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt rows rather than crashing the app.
      }
    }
    return out;
  }

  T? get(String key) {
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, T value) => box.put(key, jsonEncode(toJson(value)));

  Future<void> putAll(Map<String, T> entries) =>
      box.putAll(entries.map((k, v) => MapEntry(k, jsonEncode(toJson(v)))));

  Future<void> delete(String key) => box.delete(key);

  Future<void> clear() => box.clear();
}
