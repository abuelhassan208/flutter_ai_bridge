import 'dart:async';
import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:http/http.dart' as http;

/// Anthropic Claude provider implementation.
///
/// Supports Claude Sonnet 4, Claude Haiku, and other Anthropic models.
///
/// ```dart
/// final claude = ClaudeProvider(
///   config: AIConfig(
///     apiKey: 'sk-ant-...',
///     model: 'claude-sonnet-4-20250514',
///   ),
/// );
/// ```
class ClaudeProvider implements AIProvider {
  @override
  final AIConfig config;

  final http.Client _httpClient;
  final String _baseUrl;

  /// Anthropic API version.
  final String apiVersion;

  @override
  String get name => 'Claude';

  @override
  String get model => config.model;

  @override
  List<AICapability> get capabilities => [
        AICapability.textCompletion,
        AICapability.streaming,
        AICapability.vision,
        AICapability.structuredOutput,
      ];

  ClaudeProvider({
    required this.config,
    this.apiVersion = '2023-06-01',
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = config.baseUrl ?? 'https://api.anthropic.com/v1';

  @override
  bool supports(AICapability capability) => capabilities.contains(capability);

  @override
  Future<List<double>> embed(String text) {
    throw UnsupportedError('Claude does not support embeddings');
  }

  @override
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async {
    final stopwatch = Stopwatch()..start();

    final body = _buildRequestBody(messages, maxTokens, temperature);
    final response = await _post('/messages', body);
    stopwatch.stop();

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }

    final content = json['content'] as List? ?? [];
    final text = content
        .where((c) => (c as Map<String, dynamic>)['type'] == 'text')
        .map((c) => (c as Map<String, dynamic>)['text'] as String)
        .join();

    final usage = json['usage'] as Map<String, dynamic>? ?? {};

    return AIResponse(
      content: text,
      usage: AIUsage(
        promptTokens: usage['input_tokens'] as int? ?? 0,
        completionTokens: usage['output_tokens'] as int? ?? 0,
        estimatedCostUsd: _estimateCost(
          usage['input_tokens'] as int? ?? 0,
          usage['output_tokens'] as int? ?? 0,
        ),
      ),
      model: json['model'] as String? ?? config.model,
      provider: name,
      latency: stopwatch.elapsed,
      finishReason: json['stop_reason'] as String?,
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async* {
    final body =
        _buildRequestBody(messages, maxTokens, temperature, stream: true);

    final request = http.Request('POST', Uri.parse('$_baseUrl/messages'));
    request.headers.addAll(_headers());
    request.body = jsonEncode(body);

    final streamedResponse = await _httpClient.send(request);

    if (streamedResponse.statusCode != 200) {
      final responseBody = await streamedResponse.stream.bytesToString();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      throw _parseError(streamedResponse.statusCode, json);
    }

    String currentEvent = '';

    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('event: ')) {
        currentEvent = line.substring(7);
        continue;
      }

      if (!line.startsWith('data: ')) continue;

      final jsonStr = line.substring(6);
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;

        switch (currentEvent) {
          case 'content_block_delta':
            final delta = json['delta'] as Map<String, dynamic>?;
            if (delta?['type'] == 'text_delta') {
              final text = delta?['text'] as String? ?? '';
              if (text.isNotEmpty) {
                yield AIStreamChunk(
                  text: text,
                  provider: name,
                  model: config.model,
                );
              }
            }
            break;

          case 'message_delta':
            final usage = json['usage'] as Map<String, dynamic>?;
            yield AIStreamChunk(
              text: '',
              isComplete: true,
              finishReason: json['delta']?['stop_reason'] as String?,
              usage: usage != null
                  ? AIUsage(
                      promptTokens: 0,
                      completionTokens: usage['output_tokens'] as int? ?? 0,
                    )
                  : null,
              provider: name,
              model: config.model,
            );
            break;
        }
      } on FormatException catch (_) {
        // Skip malformed JSON chunks
      }
    }
  }

  @override
  int estimateTokens(String text) {
    // Claude tokenization is roughly similar
    return (text.length / 4).ceil();
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }

  // -- Private helpers --

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey,
        'anthropic-version': apiVersion,
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
  }) {
    // Claude uses a separate system parameter
    String? systemPrompt;
    final claudeMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message.role == AIRole.system) {
        systemPrompt = message.content;
        continue;
      }

      final role = message.role == AIRole.assistant ? 'assistant' : 'user';
      final contentParts = <Map<String, dynamic>>[];

      // Handle attachments
      if (message.attachments != null && message.attachments!.isNotEmpty) {
        for (final attachment in message.attachments!) {
          if (attachment.type == AIAttachmentType.image) {
            if (attachment.bytes != null) {
              contentParts.add({
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': attachment.mimeType ?? 'image/png',
                  'data': base64Encode(attachment.bytes!),
                },
              });
            } else if (attachment.url != null) {
              contentParts.add({
                'type': 'image',
                'source': {
                  'type': 'url',
                  'url': attachment.url,
                },
              });
            }
          } else if (attachment.type == AIAttachmentType.document) {
            if (attachment.bytes != null) {
              contentParts.add({
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': attachment.mimeType ?? 'application/pdf',
                  'data': base64Encode(attachment.bytes!),
                }
              });
            }
          }
        }
      }

      contentParts.add({'type': 'text', 'text': message.content});

      claudeMessages.add({
        'role': role,
        'content': contentParts.length == 1 ? message.content : contentParts,
      });
    }

    return {
      'model': config.model,
      'messages': claudeMessages,
      'max_tokens': maxTokens ?? config.maxTokens ?? 4096,
      if (systemPrompt != null) 'system': systemPrompt,
      if (temperature != null || config.temperature != null)
        'temperature': temperature ?? config.temperature,
      if (config.topP != null) 'top_p': config.topP,
      if (stream) 'stream': true,
      ...?config.extraParams,
    };
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
    const prices = {
      'claude-sonnet-4-20250514': (input: 3.0, output: 15.0),
      'claude-haiku-3-20250122': (input: 0.8, output: 4.0),
      'claude-3-5-sonnet-20241022': (input: 3.0, output: 15.0),
      'claude-3-haiku-20240307': (input: 0.25, output: 1.25),
    };

    final price = prices[config.model];
    if (price == null) return null;

    return (promptTokens * price.input + completionTokens * price.output) /
        1000000;
  }
}
