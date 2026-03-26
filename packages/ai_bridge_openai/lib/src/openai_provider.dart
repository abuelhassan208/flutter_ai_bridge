import 'dart:async';
import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:http/http.dart' as http;

/// OpenAI provider implementation.
///
/// Supports GPT-4o, GPT-4, GPT-3.5-turbo, and other OpenAI models.
///
/// ```dart
/// final openai = OpenAIProvider(
///   config: AIConfig(
///     apiKey: 'sk-...',
///     model: 'gpt-4o',
///   ),
/// );
///
/// final response = await openai.complete([
///   AIMessage.user('Hello!'),
/// ]);
/// ```
class OpenAIProvider
    implements AIProvider, AIAudioProvider, AIEmbeddingProvider {
  @override
  final AIConfig config;

  final http.Client _httpClient;
  final String _baseUrl;

  @override
  String get name => 'OpenAI';

  @override
  String get model => config.model;

  @override
  List<AICapability> get capabilities => [
        AICapability.textCompletion,
        AICapability.streaming,
        AICapability.vision,
        AICapability.functionCalling,
        AICapability.embeddings,
        AICapability.structuredOutput,
      ];

  OpenAIProvider({
    required this.config,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = config.baseUrl ?? 'https://api.openai.com/v1';

  @override
  bool supports(AICapability capability) => capabilities.contains(capability);

  @override
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async {
    final stopwatch = Stopwatch()..start();

    final body =
        _buildRequestBody(messages, maxTokens, temperature, tools: tools);
    final response = await _post('/chat/completions', body);
    stopwatch.stop();

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }

    final choice = (json['choices'] as List).first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    final usage = json['usage'] as Map<String, dynamic>;

    List<AIToolCall>? toolCalls;
    if (message.containsKey('tool_calls')) {
      final tCalls = message['tool_calls'] as List;
      toolCalls = tCalls
          .map((t) => AIToolCall(
                id: t['id'] as String,
                name: t['function']['name'] as String,
                arguments: jsonDecode(t['function']['arguments'] as String)
                    as Map<String, dynamic>,
              ))
          .toList();
    }

    return AIResponse(
      content: message['content'] as String? ?? '',
      usage: AIUsage(
        promptTokens: usage['prompt_tokens'] as int? ?? 0,
        completionTokens: usage['completion_tokens'] as int? ?? 0,
        estimatedCostUsd: _estimateCost(
          usage['prompt_tokens'] as int? ?? 0,
          usage['completion_tokens'] as int? ?? 0,
        ),
      ),
      model: json['model'] as String? ?? config.model,
      provider: name,
      latency: stopwatch.elapsed,
      finishReason: choice['finish_reason'] as String?,
      toolCalls: toolCalls,
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async* {
    final body = _buildRequestBody(messages, maxTokens, temperature,
        stream: true, tools: tools);

    final request =
        http.Request('POST', Uri.parse('$_baseUrl/chat/completions'));
    request.headers.addAll(_headers());
    request.body = jsonEncode(body);

    final streamedResponse = await _httpClient.send(request);

    if (streamedResponse.statusCode != 200) {
      final responseBody = await streamedResponse.stream.bytesToString();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      throw _parseError(streamedResponse.statusCode, json);
    }

    await for (final chunk in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (chunk.isEmpty || chunk == 'data: [DONE]') continue;
      if (!chunk.startsWith('data: ')) continue;

      final jsonStr = chunk.substring(6);
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isEmpty) continue;

        final delta = (choices.first as Map<String, dynamic>)['delta']
            as Map<String, dynamic>?;
        final finishReason =
            (choices.first as Map<String, dynamic>)['finish_reason'];
        final content = delta?['content'] as String? ?? '';

        if (content.isNotEmpty || finishReason != null) {
          yield AIStreamChunk(
            text: content,
            isComplete: finishReason != null,
            finishReason: finishReason as String?,
            provider: name,
            model: json['model'] as String?,
          );
        }
      } on FormatException catch (_) {
        // Skip malformed SSE chunks (e.g. partial JSON)
        continue;
      }
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    final body = {
      'model': 'text-embedding-3-small',
      'input': text,
    };

    final response = await _post('/embeddings', body);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }

    final data = (json['data'] as List).first as Map<String, dynamic>;
    return (data['embedding'] as List).cast<double>();
  }

  @override
  int estimateTokens(String text) {
    // GPT models average ~4 characters per token
    return (text.length / 4).ceil();
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }

  @override
  Future<String> speechToText(
    List<int> audioBytes, {
    String? mimeType,
    String? language,
  }) async {
    final uri = Uri.parse('$_baseUrl/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    request.fields['model'] = 'whisper-1';
    if (language != null) request.fields['language'] = language;

    // Guess extension from mime type
    String filename = 'audio.mp3';
    if (mimeType != null) {
      if (mimeType.contains('wav')) filename = 'audio.wav';
      if (mimeType.contains('m4a')) filename = 'audio.m4a';
      if (mimeType.contains('mp4')) filename = 'audio.mp4';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }
    return json['text'] as String;
  }

  @override
  Future<List<int>> textToSpeech(
    String text, {
    String? voice,
  }) async {
    final uri = Uri.parse('$_baseUrl/audio/speech');
    final response = await _httpClient
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'model': 'tts-1',
            'input': text,
            'voice':
                voice ?? 'alloy', // alloy, echo, fable, onyx, nova, shimmer
          }),
        )
        .timeout(config.timeout);

    if (response.statusCode != 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw _parseError(response.statusCode, json);
    }
    return response.bodyBytes;
  }

  // -- Private helpers --

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      };

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _httpClient
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(config.timeout);
  }

  Map<String, dynamic> _buildRequestBody(
    List<AIMessage> messages,
    int? maxTokens,
    double? temperature, {
    bool stream = false,
    List<AITool>? tools,
  }) {
    return {
      'model': config.model,
      'messages': messages.map((m) => _messageToJson(m)).toList(),
      if (maxTokens != null || config.maxTokens != null)
        'max_tokens': maxTokens ?? config.maxTokens,
      if (temperature != null || config.temperature != null)
        'temperature': temperature ?? config.temperature,
      if (config.topP != null) 'top_p': config.topP,
      if (stream) 'stream': true,
      if (tools != null && tools.isNotEmpty)
        'tools': tools
            .map((t) => {
                  'type': 'function',
                  'function': {
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.parameters,
                  }
                })
            .toList(),
      ...?config.extraParams,
    };
  }

  Map<String, dynamic> _messageToJson(AIMessage message) {
    if (message.role == AIRole.tool) {
      return {
        'role': 'tool',
        'content': message.content,
        'tool_call_id': message.toolCallId,
      };
    }

    final json = <String, dynamic>{
      'role': message.role.name,
      if (message.content.isNotEmpty) 'content': message.content,
    };

    if (message.role == AIRole.assistant &&
        message.toolCalls != null &&
        message.toolCalls!.isNotEmpty) {
      json['tool_calls'] = message.toolCalls!
          .map((tc) => {
                'id': tc.id,
                'type': 'function',
                'function': {
                  'name': tc.name,
                  'arguments': jsonEncode(tc.arguments),
                }
              })
          .toList();
    }

    // Handle vision (image attachments)
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': message.content},
      ];
      for (final attachment in message.attachments!) {
        if (attachment.type == AIAttachmentType.image) {
          if (attachment.url != null) {
            content.add({
              'type': 'image_url',
              'image_url': {'url': attachment.url},
            });
          } else if (attachment.bytes != null) {
            final b64 = base64Encode(attachment.bytes!);
            final mime = attachment.mimeType ?? 'image/png';
            content.add({
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,$b64'},
            });
          }
        }
      }
      json['content'] = content;
    }

    return json;
  }

  AIError _parseError(int statusCode, Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final type = error?['type'] as String? ?? '';

    switch (statusCode) {
      case 401:
        return AIAuthError(provider: name, message: message);
      case 429:
        return AIRateLimitError(provider: name, message: message);
      case 404:
        return AIModelNotFoundError(
          provider: name,
          message: message,
          requestedModel: config.model,
        );
      case >= 500:
        return AIServerError(
          provider: name,
          message: message,
          statusCode: statusCode,
        );
      default:
        if (type == 'invalid_request_error' && message.contains('token')) {
          return AITokenOverflowError(provider: name, message: message);
        }
        return AINetworkError(
          provider: name,
          message: message,
          statusCode: statusCode,
        );
    }
  }

  double? _estimateCost(int promptTokens, int completionTokens) {
    // Rough cost estimates per 1M tokens (as of early 2026)
    const prices = {
      'gpt-4o': (input: 2.5, output: 10.0),
      'gpt-4o-mini': (input: 0.15, output: 0.6),
      'gpt-4-turbo': (input: 10.0, output: 30.0),
      'gpt-3.5-turbo': (input: 0.5, output: 1.5),
    };

    final price = prices[config.model];
    if (price == null) return null;

    return (promptTokens * price.input + completionTokens * price.output) /
        1000000;
  }
}
