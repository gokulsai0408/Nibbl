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

/// Works with any OpenAI-compatible `/chat/completions` endpoint
/// (OpenAI, Azure OpenAI via proxy, OpenRouter, Together, a local server,
/// or your own proxy - recommended for production).
class OpenAiCompatibleService implements AiService {
  OpenAiCompatibleService(this.config, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.aiBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
              sendTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                if (config.aiApiKey.isNotEmpty) 'Authorization': 'Bearer ${config.aiApiKey}',
              },
            ),
          );

  final AppConfig config;
  final Dio _dio;

  @override
  String get displayName => '${config.aiModel} · ${config.aiHost}';

  static const _foodSchema =
      '{"items":[{"name":string,"emoji":string,"serving":string,"grams":number,'
      '"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number}]}';

  static const _foodSystemPrompt = '$foodAnalysisGuidelines\n\nRespond with ONLY a JSON object matching: $_foodSchema';

  @override
  Future<List<LoggedFood>> analyzePhotos(List<Uint8List> photos, {String? hint, List<String> tags = const []}) async {
    final content = await _complete(
      model: config.aiVisionModel,
      json: true,
      messages: [
        {'role': 'system', 'content': _foodSystemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': photoInstruction(photos.length, hint: hint, tags: tags)},
            for (final bytes in photos)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(bytes)}', 'detail': 'high'},
              },
          ],
        },
      ],
    );
    return AiJsonParser.parseItems(content);
  }

  @override
  Future<List<LoggedFood>> parseText(String description) async {
    final content = await _complete(
      model: config.aiModel,
      json: true,
      messages: [
        {'role': 'system', 'content': _foodSystemPrompt},
        {'role': 'user', 'content': 'Itemize what I ate: $description'},
      ],
    );
    return AiJsonParser.parseItems(content);
  }

  @override
  Future<(Food, bool)> identifyProduct({
    required String barcode,
    List<Uint8List> photos = const [],
    String? name,
    String? brand,
  }) async {
    final content = await _complete(
      model: photos.isEmpty ? config.aiModel : config.aiVisionModel,
      json: true,
      messages: [
        {
          'role': 'system',
          'content':
              '${LabelPrompts.system}\n\nRespond with ONLY a JSON object with keys: '
              '${LabelPrompts.schema['required']}',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': LabelPrompts.userMessage(photos: photos.length, name: name, brand: brand)},
            for (final bytes in photos)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(bytes)}', 'detail': 'high'},
              },
          ],
        },
      ],
    );
    return LabelPrompts.parse(content, barcode: barcode);
  }

  @override
  Future<DrinkEstimate> estimateDrink(Uint8List jpegBytes, {String? hint}) async {
    final content = await _complete(
      model: config.aiVisionModel,
      json: true,
      messages: [
        {
          'role': 'system',
          'content':
              '${DrinkPrompts.system}\n\nRespond with ONLY a JSON object with keys: ${DrinkPrompts.schema['required']}',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': DrinkPrompts.userMessage(hint: hint)},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(jpegBytes)}', 'detail': 'high'},
            },
          ],
        },
      ],
    );
    return DrinkPrompts.parse(content);
  }

  @override
  Future<Recipe> suggestRecipe(RecipeRequest request) async {
    final content = await _complete(
      model: config.aiModel,
      json: true,
      temperature: 0.7,
      messages: [
        {
          'role': 'system',
          'content':
              '${RecipePrompts.recipeSystem}\n\nRespond with ONLY a JSON object with keys: '
              '${RecipePrompts.recipeSchema['required']}',
        },
        {'role': 'user', 'content': RecipePrompts.recipeUserMessage(request)},
      ],
    );
    return RecipePrompts.parseRecipe(content);
  }

  @override
  Future<List<(String, String)>> scanPantry(Uint8List jpegBytes) async {
    final content = await _complete(
      model: config.aiVisionModel,
      json: true,
      messages: [
        {
          'role': 'system',
          'content': '${RecipePrompts.pantryScanSystem} Respond with ONLY {"items":[{"name":string,"emoji":string}]}',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'What ingredients do I have?'},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(jpegBytes)}', 'detail': 'low'},
            },
          ],
        },
      ],
    );
    return RecipePrompts.parsePantry(content);
  }

  @override
  Future<String> coachReply({required List<ChatMessage> history, required String context}) async {
    final recent = history.length > 16 ? history.sublist(history.length - 16) : history;
    return _complete(
      model: config.aiModel,
      json: false,
      temperature: 0.6,
      messages: [
        {'role': 'system', 'content': coachSystemPrompt(context)},
        for (final m in recent) {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': m.text},
      ],
    );
  }

  Future<String> _complete({
    required String model,
    required List<Map<String, dynamic>> messages,
    required bool json,
    double temperature = 0.2,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'temperature': temperature,
          if (json) 'response_format': {'type': 'json_object'},
        },
      );
      final choices = res.data?['choices'] as List?;
      final content = (choices?.firstOrNull as Map?)?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiException('The AI returned an empty response.');
      }
      return content;
    } on DioException catch (e) {
      throw AiException(_describe(e));
    }
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The AI took too long to respond. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Can\'t reach the AI service. Are you online?';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401 || code == 403) return 'The AI service rejected the request (auth error $code).';
        if (code == 429) return 'Too many requests right now. Give it a moment and retry.';
        if (code >= 500) return 'The AI service is having trouble ($code). Try again shortly.';
        return 'The AI request failed ($code).';
      default:
        return 'Something went wrong talking to the AI.';
    }
  }
}
