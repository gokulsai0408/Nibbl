import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AiProvider { anthropic, openai }

/// Runtime configuration.
///
/// Resolution order (first non-empty wins):
///   1. `--dart-define=KEY=value` at build time
///   2. the bundled `.env` asset
///   3. built-in defaults
///
/// SECURITY: anything compiled into an app binary can be extracted. In
/// production, set [aiBaseUrl] to your own proxy (see `proxy/worker.js`)
/// which holds the provider key server-side, and leave [aiApiKey] empty.
class AppConfig {
  const AppConfig({
    required this.aiBaseUrl,
    required this.aiApiKey,
    required this.aiModel,
    required this.aiVisionModel,
    required this.useMockAi,
    required this.provider,
    this.supabaseUrl = '',
    this.supabaseKey = '',
  });

  final String aiBaseUrl;
  final String aiApiKey;
  final String aiModel;
  final String aiVisionModel;
  final bool useMockAi;

  /// `anthropic` (native Claude Messages API) or `openai` (any OpenAI-compatible API).
  final AiProvider provider;

  /// Supabase project for the social features (empty = offline demo).
  final String supabaseUrl;
  final String supabaseKey;

  bool get hasSocial => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// True when requests go to a real OpenAI-compatible endpoint.
  bool get hasLiveAi => !useMockAi && aiBaseUrl.isNotEmpty;

  /// Same config, pointed at a different model (used by the in-app model switch).
  AppConfig withModel(String model) => AppConfig(
        aiBaseUrl: aiBaseUrl,
        aiApiKey: aiApiKey,
        aiModel: model,
        aiVisionModel: model,
        useMockAi: useMockAi,
        provider: provider,
        supabaseUrl: supabaseUrl,
        supabaseKey: supabaseKey,
      );

  String get aiHost {
    final uri = Uri.tryParse(aiBaseUrl);
    return (uri == null || uri.host.isEmpty) ? aiBaseUrl : uri.host;
  }

  static const _defBaseUrl = String.fromEnvironment('AI_BASE_URL');
  static const _defApiKey = String.fromEnvironment('AI_API_KEY');
  static const _defModel = String.fromEnvironment('AI_MODEL');
  static const _defVisionModel = String.fromEnvironment('AI_VISION_MODEL');
  static const _defUseMock = String.fromEnvironment('USE_MOCK_AI');
  static const _defProvider = String.fromEnvironment('AI_PROVIDER');
  static const _defSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defSupabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static Future<AppConfig> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    String read(String defined, String key, String fallback) {
      if (defined.isNotEmpty) return defined;
      final fromEnv = dotenv.isInitialized ? dotenv.maybeGet(key) : null;
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
      return fallback;
    }

    final apiKey = read(_defApiKey, 'AI_API_KEY', '');
    var baseUrl = read(_defBaseUrl, 'AI_BASE_URL', '');

    // Provider: explicit AI_PROVIDER wins; otherwise detect a Claude key or URL.
    final providerRaw = read(_defProvider, 'AI_PROVIDER', '').toLowerCase();
    final provider = switch (providerRaw) {
      'anthropic' || 'claude' => AiProvider.anthropic,
      'openai' => AiProvider.openai,
      _ =>
        (apiKey.startsWith('sk-ant-') || baseUrl.contains('anthropic.com')) ? AiProvider.anthropic : AiProvider.openai,
    };
    if (provider == AiProvider.anthropic && baseUrl.isEmpty && apiKey.isNotEmpty) {
      baseUrl = 'https://api.anthropic.com';
    }

    final defaultModel = provider == AiProvider.anthropic ? 'claude-opus-5-5' : 'gpt-4o-mini';
    final model = read(_defModel, 'AI_MODEL', defaultModel);
    final mockRaw = read(_defUseMock, 'USE_MOCK_AI', baseUrl.isEmpty ? 'true' : 'false');

    return AppConfig(
      aiBaseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      aiApiKey: apiKey,
      aiModel: model,
      aiVisionModel: read(_defVisionModel, 'AI_VISION_MODEL', model),
      useMockAi: mockRaw.toLowerCase() == 'true' || baseUrl.isEmpty,
      provider: provider,
      supabaseUrl: read(_defSupabaseUrl, 'SUPABASE_URL', ''),
      supabaseKey: read(_defSupabaseKey, 'SUPABASE_KEY', read('', 'SUPABASE_ANON_KEY', '')),
    );
  }
}
