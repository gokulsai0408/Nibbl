import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/ai/anthropic_ai_service.dart';
import '../../data/ai/mock_ai_service.dart';
import '../../data/ai/openai_ai_service.dart';
import '../../data/backup/backup_service.dart';
import '../../data/local/hive_store.dart';
import '../../data/remote/open_food_facts_api.dart';
import '../../data/repositories/hive_repositories.dart';
import '../../domain/ai/ai_service.dart';
import '../../domain/repositories/repositories.dart';
import 'profile_settings_providers.dart';

/// Overridden in `main()` with the loaded config.
final appConfigProvider = Provider<AppConfig>((ref) => throw UnimplementedError('appConfigProvider not overridden'));

final profileRepoProvider = Provider<ProfileRepository>(
  (ref) => HiveProfileRepository(HiveStore.box(HiveStore.profile)),
);
final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => HiveSettingsRepository(HiveStore.box(HiveStore.settings)),
);
final logRepoProvider = Provider<LogRepository>((ref) => HiveLogRepository(HiveStore.box(HiveStore.logs)));
final foodRepoProvider = Provider<FoodRepository>((ref) => HiveFoodRepository(HiveStore.box(HiveStore.foods)));
final weightRepoProvider = Provider<WeightRepository>((ref) => HiveWeightRepository(HiveStore.box(HiveStore.weights)));
final dayMetaRepoProvider = Provider<DayMetaRepository>(
  (ref) => HiveDayMetaRepository(HiveStore.box(HiveStore.dayMeta)),
);
final templateRepoProvider = Provider<TemplateRepository>(
  (ref) => HiveTemplateRepository(HiveStore.box(HiveStore.templates)),
);
final chatRepoProvider = Provider<ChatRepository>((ref) => HiveChatRepository(HiveStore.box(HiveStore.chat)));

final aiServiceProvider = Provider<AiService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasLiveAi) return MockAiService();
  // The in-app Opus/Haiku switch overrides AI_MODEL for Claude.
  final model = ref.watch(settingsProvider.select((s) => s.aiModel));
  return switch (config.provider) {
    AiProvider.anthropic => AnthropicAiService(config.withModel(model.id)),
    AiProvider.openai => OpenAiCompatibleService(config),
  };
});

final openFoodFactsProvider = Provider<OpenFoodFactsApi>((ref) => OpenFoodFactsApi());
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());
