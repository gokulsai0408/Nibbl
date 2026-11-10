import '../entities/food.dart';
import '../entities/food_log.dart';
import '../entities/tracking.dart';
import '../entities/user_profile.dart';

/// Repository contracts. The presentation layer depends only on these;
/// implementations live in `data/repositories`.

abstract interface class ProfileRepository {
  UserProfile? load();
  Future<void> save(UserProfile profile);
  Future<void> clear();
}

abstract interface class SettingsRepository {
  AppSettings load();
  Future<void> save(AppSettings settings);
}

abstract interface class LogRepository {
  List<FoodLog> all();
  Future<void> upsert(FoodLog log);
  Future<void> upsertAll(Iterable<FoodLog> logs);
  Future<void> delete(String id);
}

abstract interface class FoodRepository {
  /// Built-in foods plus custom/cached foods.
  List<Food> all();
  Future<void> upsert(Food food);
  Future<void> delete(String id);
  Set<String> favorites();
  Future<void> setFavorites(Set<String> ids);
}

abstract interface class WeightRepository {
  List<WeightEntry> all();
  Future<void> upsert(WeightEntry entry);
  Future<void> delete(String id);
}

abstract interface class DayMetaRepository {
  Map<String, DayMeta> all();
  Future<void> save(DayMeta meta);
}

abstract interface class TemplateRepository {
  List<MealTemplate> all();
  Future<void> upsert(MealTemplate template);
  Future<void> delete(String id);
}

abstract interface class ChatRepository {
  List<ChatMessage> all();
  Future<void> add(ChatMessage message);
  Future<void> clear();
}
