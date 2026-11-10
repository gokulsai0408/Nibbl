import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../domain/ai/ai_service.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/entities/tracking.dart';
import 'ai_json_parser.dart';
import 'coach_prompt.dart';
import 'drink_prompt.dart';
import 'food_prompt.dart';
import 'label_prompt.dart';
import 'recipe_prompt.dart';

/// Claude via the native Anthropic Messages API (`POST /v1/messages`).
///
/// Dart has no official Anthropic SDK, so this calls the REST API directly.
/// Food analysis uses structured outputs (`output_config.format`) so the
/// response is always schema-valid JSON.
class AnthropicAiService implements AiService {
  AnthropicAiService(this.config, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.aiBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              // Claude Opus 5.5 always thinks before answering; give it room.
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 60),
              headers: {
                'content-type': 'application/json',
                'anthropic-version': '2026-10-21',
                if (config.aiApiKey.isNotEmpty) 'x-api-key': config.aiApiKey,
              },
            ),
          );

  final AppConfig config;
  final Dio _dio;

  /// Models that accept the server-side refusal fallback (`fallbacks: "default"`).
  /// Haiku has no server-side fallback, so it's never sent there.
  static bool _supportsFallback(String model) =>
      model.startsWith('claude-opus-5') || model.startsWith('claude-sonnet-5-5') || model.startsWith('claude-fable-5');

  @override
  String get displayName => switch (config.aiModel) {
    'claude-opus-5-5' => 'Claude Opus 5.5',
    'claude-haiku-5-5' => 'Claude Haiku 5.5',
    final m => '$m · Claude',
  };

  static const _foodSystemPrompt = foodAnalysisGuidelines;

  /// JSON schema for structured outputs.
  static const Map<String, dynamic> _foodSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'emoji': {'type': 'string'},
            'serving': {'type': 'string'},
            'grams': {'type': 'number'},
            'calories': {'type': 'number'},
            'protein': {'type': 'number'},
            'carbs': {'type': 'number'},
            'fat': {'type': 'number'},
            'confidence': {'type': 'number'},
          },
          'required': ['name', 'emoji', 'serving', 'grams', 'calories', 'protein', 'carbs', 'fat', 'confidence'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  @override
  Future<List<LoggedFood>> analyzePhotos(List<Uint8List> photos, {String? hint, List<String> tags = const []}) async {
    final text = await _send(
      model: config.aiVisionModel,
      system: _foodSystemPrompt,
      effort: 'high', // portion estimation from photos benefits from more thinking
      schema: _foodSchema,
      messages: [
        {
          'role': 'user',
          'content': [
            for (final (i, bytes) in photos.indexed) ...[
              if (photos.length > 1) {'type': 'text', 'text': 'Photo ${i + 1}:'},
              {
                'type': 'image',
                'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(bytes)},
              },
            ],
            {'type': 'text', 'text': photoInstruction(photos.length, hint: hint, tags: tags)},
          ],
        },
      ],
    );
    return AiJsonParser.parseItems(text);
  }

  @override
  Future<List<LoggedFood>> parseText(String description) async {
    final text = await _send(
      model: config.aiModel,
      system: _foodSystemPrompt,
      effort: 'medium',
      schema: _foodSchema,
      messages: [
        {'role': 'user', 'content': 'Itemize what I ate: $description'},
      ],
    );
    return AiJsonParser.parseItems(text);
  }

  @override
  Future<(Food, bool)> identifyProduct({
    required String barcode,
    List<Uint8List> photos = const [],
    String? name,
    String? brand,
  }) async {
    final text = await _send(
      model: photos.isEmpty ? config.aiModel : config.aiVisionModel,
      system: LabelPrompts.system,
      effort: 'low',
      schema: LabelPrompts.schema,
      messages: [
        {
          'role': 'user',
          'content': [
            for (final bytes in photos)
              {
                'type': 'image',
                'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(bytes)},
              },
            {'type': 'text', 'text': LabelPrompts.userMessage(photos: photos.length, name: name, brand: brand)},
          ],
        },
      ],
    );
    return LabelPrompts.parse(text, barcode: barcode);
  }

  @override
  Future<DrinkEstimate> estimateDrink(Uint8List jpegBytes, {String? hint}) async {
    final text = await _send(
      model: config.aiVisionModel,
      system: DrinkPrompts.system,
      effort: 'low',
      schema: DrinkPrompts.schema,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpegBytes)},
            },
            {'type': 'text', 'text': DrinkPrompts.userMessage(hint: hint)},
          ],
        },
      ],
    );
    return DrinkPrompts.parse(text);
  }

  @override
  Future<Recipe> suggestRecipe(RecipeRequest request) async {
    final text = await _send(
      model: config.aiModel,
      system: RecipePrompts.recipeSystem,
      effort: 'medium',
      schema: RecipePrompts.recipeSchema,
      messages: [
        {'role': 'user', 'content': RecipePrompts.recipeUserMessage(request)},
      ],
    );
    return RecipePrompts.parseRecipe(text);
  }

  @override
  Future<List<(String, String)>> scanPantry(Uint8List jpegBytes) async {
    final text = await _send(
      model: config.aiVisionModel,
      system: RecipePrompts.pantryScanSystem,
      effort: 'low',
      schema: RecipePrompts.pantrySchema,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpegBytes)},
            },
            {'type': 'text', 'text': 'What ingredients do I have?'},
          ],
        },
      ],
    );
    return RecipePrompts.parsePantry(text);
  }

  @override
  Future<String> coachReply({required List<ChatMessage> history, required String context}) async {
    final recent = history.length > 16 ? history.sublist(history.length - 16) : history;
    // The Messages API requires the conversation to start with a user turn.
    final firstUser = recent.indexWhere((m) => m.role == ChatRole.user);
    final turns = firstUser < 0 ? <ChatMessage>[] : recent.sublist(firstUser);
    return _send(
      model: config.aiModel,
      effort: 'medium',
      system: coachSystemPrompt(context),
      messages: [
        for (final m in turns) {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': m.text},
      ],
    );
  }

  Future<String> _send({
    required String model,
    required String system,
    required String effort,
    required List<Map<String, dynamic>> messages,
    Map<String, dynamic>? schema,
  }) async {
    try {
      final fallback = _supportsFallback(model);
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/messages',
        // If a safety classifier declines, the API re-runs the request on a
        // recommended fallback model (only where the model supports it).
        options: fallback ? Options(headers: {'anthropic-beta': 'server-side-fallback-2026-07-01'}) : null,
        data: {
          'model': model,
          'max_tokens': 16000,
          'system': system,
          'messages': messages,
          if (fallback) 'fallbacks': 'default',
          'output_config': {
            'effort': effort,
            if (schema != null) 'format': {'type': 'json_schema', 'schema': schema},
          },
        },
      );
      final data = res.data ?? const {};

      // Always check stop_reason before reading content.
      final stop = data['stop_reason'];
      if (stop == 'refusal') {
        throw const AiException('Claude declined this request. Try rephrasing it.');
      }
      if (stop == 'max_tokens') {
        throw const AiException('The response was cut off. Try a shorter description.');
      }

      // Content can include thinking blocks; only text blocks hold the answer.
      final text = ((data['content'] as List?) ?? const [])
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String? ?? '')
          .join()
          .trim();
      if (text.isEmpty) throw const AiException('Claude returned an empty response.');
      return text;
    } on DioException catch (e) {
      throw AiException(_describe(e));
    }
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Claude took too long to respond. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Can\'t reach the Claude API. Are you online?';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        final apiMsg = body is Map ? ((body['error'] as Map?)?['message'] as String?) : null;
        if (code == 401) return 'Claude rejected the API key (401). Check AI_API_KEY in .env.';
        if (code == 403) return 'This API key doesn\'t have access to that model (403).';
        if (code == 404) return 'Model not found (404). Check AI_MODEL in .env.';
        if (code == 413) return 'That photo is too large to send. Try another one.';
        if (code == 429) return 'Rate limit reached. Give it a moment and retry.';
        if (code == 529 || code >= 500) return 'Claude is overloaded right now ($code). Try again shortly.';
        final detail = apiMsg == null ? '' : ' - $apiMsg';
        return 'Claude request failed ($code)$detail';
      default:
        return 'Something went wrong talking to Claude.';
    }
  }
}
