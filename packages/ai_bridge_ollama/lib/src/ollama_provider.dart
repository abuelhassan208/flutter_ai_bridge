import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_bridge_core/ai_bridge_core.dart';

/// Provider for local Ollama instances.
class OllamaProvider implements AIProvider {
  @override
  final AIConfig config;

  final http.Client _client;
  final String _baseUrl;

  /// Creates an [OllamaProvider].
  ///
  /// [baseUrl] defaults to 'http://localhost:11434'. NOTE: on Android emulators,
  /// you might need 'http://10.0.2.2:11434' to reach the host machine.
  OllamaProvider({
    required this.config,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'http://localhost:11434';

  @override
  String get name => 'Ollama';

  @override
  String get model => config.model;

  @override
  List<AICapability> get capabilities => const [
        AICapability.textCompletion,
        AICapability.streaming,
        AICapability.embeddings,
        AICapability.vision, // Supported by LLava and others
      ];

  @override
  bool supports(AICapability capability) => capabilities.contains(capability);

  @override
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async {
    final startTime = DateTime.now();

    final requestBody = {
      'model': model,
      'messages': _mapMessages(messages),
      'stream': false,
      if (temperature != null || config.temperature != null)
        'options': {
          'temperature': temperature ?? config.temperature,
          if (maxTokens != null || config.maxTokens != null)
            'num_predict': maxTokens ?? config.maxTokens,
        }
    };

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        _handleError(response.statusCode, response.body);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final messageData = data['message'] as Map;

      return AIResponse(
        content: messageData['content'] as String,
        usage: AIUsage(
          promptTokens: data['prompt_eval_count'] as int? ?? 0,
          completionTokens: data['eval_count'] as int? ?? 0,
        ),
        model: data['model'] as String? ?? model,
        provider: name,
        latency: DateTime.now().difference(startTime),
      );
    } catch (e) {
      if (e is AIError) rethrow;
      throw AINetworkError(provider: name, originalError: e);
    }
  }

  @override
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async* {
    final requestBody = {
      'model': model,
      'messages': _mapMessages(messages),
      'stream': true,
      if (temperature != null || config.temperature != null)
        'options': {
          'temperature': temperature ?? config.temperature,
          if (maxTokens != null || config.maxTokens != null)
            'num_predict': maxTokens ?? config.maxTokens,
        }
    };

    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(requestBody);

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        final bodyStart = await response.stream.bytesToString();
        _handleError(response.statusCode, bodyStart);
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) continue;

        try {
          final data = jsonDecode(line) as Map<String, dynamic>;
          final msg = data['message'] as Map?;
          final isDone = data['done'] as bool? ?? false;

          yield AIStreamChunk(
            text: msg?['content'] as String? ?? '',
            isComplete: isDone,
            provider: name,
            model: data['model'] as String? ?? model,
            usage: isDone
                ? AIUsage(
                    promptTokens: data['prompt_eval_count'] as int? ?? 0,
                    completionTokens: data['eval_count'] as int? ?? 0,
                  )
                : null,
          );
        } on FormatException catch (_) {
          // Ignore parsing errors for partial JSON chunks
        }
      }
    } catch (e) {
      if (e is AIError) rethrow;
      throw AINetworkError(provider: name, originalError: e);
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': text,
        }),
      );

      if (response.statusCode != 200) {
        _handleError(response.statusCode, response.body);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('embedding')) {
        return List<double>.from((data['embedding'] as List)
            .map((x) => x is num ? x.toDouble() : x));
      } else if (data.containsKey('embeddings')) {
        return List<double>.from((data['embeddings'][0] as List)
            .map((x) => x is num ? x.toDouble() : x));
      }
      return [];
    } catch (e) {
      if (e is AIError) rethrow;
      throw AINetworkError(provider: name, originalError: e);
    }
  }

  @override
  int estimateTokens(String text) {
    // Rough estimate (letters / 4)
    return (text.length / 4).ceil();
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }

  List<Map<String, dynamic>> _mapMessages(List<AIMessage> messages) {
    return messages.map((m) {
      final map = <String, dynamic>{
        'role': m.role.name,
        'content': m.content,
      };

      if (m.attachments != null && m.attachments!.isNotEmpty) {
        final images = <String>[];
        for (final att in m.attachments!) {
          if (att.type == AIAttachmentType.image && att.bytes != null) {
            images.add(base64Encode(att.bytes!));
          }
        }
        if (images.isNotEmpty) {
          map['images'] = images;
        }
      }

      return map;
    }).toList();
  }

  Never _handleError(int statusCode, String body) {
    if (statusCode == 404) {
      throw AIModelNotFoundError(
        provider: name,
        message: 'Model not found: $body',
      );
    }
    throw AIServerError(
      provider: name,
      statusCode: statusCode,
      message: body,
    );
  }
}
