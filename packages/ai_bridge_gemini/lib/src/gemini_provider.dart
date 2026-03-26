import 'dart:async';
import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:http/http.dart' as http;

/// Google Gemini provider implementation.
///
/// Supports Gemini 2.0 Flash, Gemini 1.5 Pro, and other Gemini models.
///
/// ```dart
/// final gemini = GeminiProvider(
///   config: AIConfig(
///     apiKey: 'AI...',
///     model: 'gemini-2.0-flash',
///   ),
/// );
/// ```
class GeminiProvider implements AIProvider {
  @override
  final AIConfig config;

  final http.Client _httpClient;
  final String _baseUrl;

  @override
  String get name => 'Gemini';

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

  GeminiProvider({
    required this.config,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = config.baseUrl ??
            'https://generativelanguage.googleapis.com/v1beta';

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
    final url =
        '$_baseUrl/models/${config.model}:generateContent?key=${config.apiKey}';
    final response = await _httpClient
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(config.timeout);

    stopwatch.stop();

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }

    final candidates = json['candidates'] as List? ?? [];
    if (candidates.isEmpty) {
      throw AIContentFilterError(
        provider: name,
        message: 'No candidates returned — content may have been filtered',
      );
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = (content?['parts'] as List?) ?? [];

    String text = '';
    List<AIToolCall>? toolCalls;

    for (final p in parts) {
      if (p is Map<String, dynamic>) {
        if (p.containsKey('text')) {
          text += p['text'] as String;
        } else if (p.containsKey('functionCall')) {
          final fc = p['functionCall'] as Map<String, dynamic>;
          toolCalls ??= [];
          toolCalls.add(AIToolCall(
            id: fc['name'] as String, // Gemini uses name as the identifier
            name: fc['name'] as String,
            arguments: fc['args'] as Map<String, dynamic>? ?? {},
          ));
        }
      }
    }

    final usageMetadata = json['usageMetadata'] as Map<String, dynamic>? ?? {};

    return AIResponse(
      content: text,
      usage: AIUsage(
        promptTokens: usageMetadata['promptTokenCount'] as int? ?? 0,
        completionTokens: usageMetadata['candidatesTokenCount'] as int? ?? 0,
        estimatedCostUsd: _estimateCost(
          usageMetadata['promptTokenCount'] as int? ?? 0,
          usageMetadata['candidatesTokenCount'] as int? ?? 0,
        ),
      ),
      model: config.model,
      provider: name,
      latency: stopwatch.elapsed,
      finishReason: candidate['finishReason'] as String?,
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
    final body =
        _buildRequestBody(messages, maxTokens, temperature, tools: tools);
    final url =
        '$_baseUrl/models/${config.model}:streamGenerateContent?alt=sse&key=${config.apiKey}';

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
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
      if (chunk.isEmpty) continue;
      if (!chunk.startsWith('data: ')) continue;

      final jsonStr = chunk.substring(6);
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final candidates = json['candidates'] as List? ?? [];
        if (candidates.isEmpty) continue;

        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List?) ?? [];
        final text = parts
            .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
            .join();

        final finishReason = candidate['finishReason'] as String?;

        AIUsage? usage;
        final usageMetadata = json['usageMetadata'] as Map<String, dynamic>?;
        if (usageMetadata != null) {
          usage = AIUsage(
            promptTokens: usageMetadata['promptTokenCount'] as int? ?? 0,
            completionTokens:
                usageMetadata['candidatesTokenCount'] as int? ?? 0,
          );
        }

        if (text.isNotEmpty) {
          yield AIStreamChunk(
            text: text,
            isComplete: finishReason == 'STOP',
            finishReason: finishReason,
            usage: usage,
            provider: name,
            model: config.model,
          );
        }
      } on FormatException catch (_) {
        // Skip malformed JSON chunks
      }
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    final url =
        '$_baseUrl/models/text-embedding-004:embedContent?key=${config.apiKey}';

    final response = await _httpClient.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'models/text-embedding-004',
        'content': {
          'parts': [
            {'text': text}
          ]
        },
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw _parseError(response.statusCode, json);
    }

    final embedding = json['embedding'] as Map<String, dynamic>;
    return (embedding['values'] as List).cast<double>();
  }

  @override
  int estimateTokens(String text) {
    // Gemini tokenization is roughly similar to GPT
    return (text.length / 4).ceil();
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }

  // -- Private helpers --

  Map<String, dynamic> _buildRequestBody(
    List<AIMessage> messages,
    int? maxTokens,
    double? temperature, {
    List<AITool>? tools,
  }) {
    // Separate system instruction from conversation
    final systemParts = <String>[];
    final contents = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message.role == AIRole.system) {
        systemParts.add(message.content);
        continue;
      }

      if (message.role == AIRole.tool) {
        contents.add({
          'role': 'user', // Gemini expects tool responses to come from user
          'parts': [
            {
              'functionResponse': {
                'name': message.toolCallId ?? 'unknown',
                'response': {'result': message.content}
              }
            }
          ]
        });
        continue;
      }

      final role = message.role == AIRole.assistant ? 'model' : 'user';
      var parts = <Map<String, dynamic>>[];

      if (message.content.isNotEmpty) {
        parts.add({'text': message.content});
      }

      // Handle tool calls in assistant messages
      if (message.role == AIRole.assistant && message.toolCalls != null) {
        for (final tc in message.toolCalls!) {
          parts.add({
            'functionCall': {
              'name': tc.name,
              'args': tc.arguments,
            }
          });
        }
      }

      // Handle multimodal attachments
      if (message.attachments != null) {
        for (final attachment in message.attachments!) {
          if (attachment.bytes != null) {
            String mime = attachment.mimeType ?? '';
            if (mime.isEmpty) {
              switch (attachment.type) {
                case AIAttachmentType.image:
                  mime = 'image/png';
                  break;
                case AIAttachmentType.audio:
                  mime = 'audio/mp3';
                  break;
                case AIAttachmentType.video:
                  mime = 'video/mp4';
                  break;
                case AIAttachmentType.document:
                  mime = 'application/pdf';
                  break;
                case AIAttachmentType.file:
                  mime = 'application/octet-stream';
                  break;
              }
            }
            parts.add({
              'inline_data': {
                'mime_type': mime,
                'data': base64Encode(attachment.bytes!),
              },
            });
          }
        }
      }

      contents.add({'role': role, 'parts': parts});
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        if (maxTokens != null || config.maxTokens != null)
          'maxOutputTokens': maxTokens ?? config.maxTokens,
        if (temperature != null || config.temperature != null)
          'temperature': temperature ?? config.temperature,
        if (config.topP != null) 'topP': config.topP,
      },
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = [
        {
          'functionDeclarations': tools
              .map((t) => {
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.parameters,
                  })
              .toList(),
        }
      ];
    }

    if (systemParts.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': systemParts.map((s) => {'text': s}).toList(),
      };
    }

    return body;
  }

  AIError _parseError(int statusCode, Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';

    switch (statusCode) {
      case 400:
        if (message.contains('API key')) {
          return AIAuthError(provider: name, message: message);
        }
        if (message.contains('token') || message.contains('limit')) {
          return AITokenOverflowError(provider: name, message: message);
        }
        return AINetworkError(
          provider: name,
          message: message,
          statusCode: statusCode,
        );
      case 403:
        return AIAuthError(provider: name, message: message);
      case 404:
        return AIModelNotFoundError(
          provider: name,
          message: message,
          requestedModel: config.model,
        );
      case 429:
        return AIRateLimitError(provider: name, message: message);
      case >= 500:
        return AIServerError(
          provider: name,
          message: message,
          statusCode: statusCode,
        );
      default:
        return AINetworkError(
          provider: name,
          message: message,
          statusCode: statusCode,
        );
    }
  }

  double? _estimateCost(int promptTokens, int completionTokens) {
    const prices = {
      'gemini-2.0-flash': (input: 0.1, output: 0.4),
      'gemini-1.5-flash': (input: 0.075, output: 0.3),
      'gemini-1.5-pro': (input: 1.25, output: 5.0),
    };

    final price = prices[config.model];
    if (price == null) return null;

    return (promptTokens * price.input + completionTokens * price.output) /
        1000000;
  }
}
