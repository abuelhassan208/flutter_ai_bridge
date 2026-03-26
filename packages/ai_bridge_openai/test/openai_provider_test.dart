import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testConfig = AIConfig(apiKey: 'sk-test-key', model: 'gpt-4o');

  /// Helper: creates a MockClient that returns a fixed JSON body.
  MockClient _mockResponse(int statusCode, Map<String, dynamic> body) {
    return MockClient((request) async {
      return http.Response(jsonEncode(body), statusCode,
          headers: {'content-type': 'application/json'});
    });
  }

  // ─── Fixtures ───────────────────────────────────────────────

  Map<String, dynamic> _completionResponse({
    String content = 'Hello from GPT!',
    int promptTokens = 10,
    int completionTokens = 20,
    String? finishReason = 'stop',
    List<Map<String, dynamic>>? toolCalls,
  }) {
    final message = <String, dynamic>{
      'role': 'assistant',
      'content': content,
    };
    if (toolCalls != null) message['tool_calls'] = toolCalls;

    return {
      'id': 'chatcmpl-test',
      'object': 'chat.completion',
      'model': 'gpt-4o',
      'choices': [
        {
          'index': 0,
          'message': message,
          'finish_reason': finishReason,
        }
      ],
      'usage': {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': promptTokens + completionTokens,
      },
    };
  }

  // ─── complete() ─────────────────────────────────────────────

  group('OpenAIProvider.complete()', () {
    test('parses successful response correctly', () async {
      final client = _mockResponse(200, _completionResponse());
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Hi')]);

      expect(response.content, 'Hello from GPT!');
      expect(response.provider, 'OpenAI');
      expect(response.model, 'gpt-4o');
      expect(response.usage.promptTokens, 10);
      expect(response.usage.completionTokens, 20);
      expect(response.usage.totalTokens, 30);
      expect(response.finishReason, 'stop');
      expect(response.latency, isNotNull);
    });

    test('parses tool calls in response', () async {
      final fixture = _completionResponse(
        content: '',
        finishReason: 'tool_calls',
        toolCalls: [
          {
            'id': 'call_abc123',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"city":"Cairo","unit":"celsius"}',
            },
          }
        ],
      );
      final client = _mockResponse(200, fixture);
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Weather?')]);

      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.id, 'call_abc123');
      expect(response.toolCalls!.first.name, 'get_weather');
      expect(response.toolCalls!.first.arguments['city'], 'Cairo');
      expect(response.toolCalls!.first.arguments['unit'], 'celsius');
    });

    test('sends correct request body with tools', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      final tools = [
        AITool(
          name: 'search',
          description: 'Search the web',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
          },
        ),
      ];

      await provider.complete([AIMessage.user('Find info')], tools: tools);

      expect(capturedBody['model'], 'gpt-4o');
      expect(capturedBody['tools'], isNotNull);
      expect(
          (capturedBody['tools'] as List).first['function']['name'], 'search');
    });

    test('sends Authorization header', () async {
      late Map<String, String> capturedHeaders;
      final client = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedHeaders['authorization'], 'Bearer sk-test-key');
      expect(capturedHeaders['content-type'], 'application/json');
    });

    test('maps image attachments to image_url blocks', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      await provider.complete([
        AIMessage(
          role: AIRole.user,
          content: 'What is this?',
          attachments: [AIAttachment.imageUrl('https://example.com/img.png')],
        ),
      ]);

      final messages = capturedBody['messages'] as List;
      final userMsg = messages.last as Map<String, dynamic>;
      final content = userMsg['content'] as List;
      expect(content.any((c) => c['type'] == 'image_url'), isTrue);
    });
  });

  // ─── Error Mapping ──────────────────────────────────────────

  group('OpenAIProvider error mapping', () {
    test('401 → AIAuthError', () async {
      final client = _mockResponse(401, {
        'error': {'message': 'Invalid API key', 'type': 'invalid_api_key'},
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIAuthError>()),
      );
    });

    test('429 → AIRateLimitError', () async {
      final client = _mockResponse(429, {
        'error': {
          'message': 'Rate limit exceeded',
          'type': 'rate_limit_exceeded'
        },
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIRateLimitError>()),
      );
    });

    test('404 → AIModelNotFoundError', () async {
      final client = _mockResponse(404, {
        'error': {
          'message': 'Model not found',
          'type': 'invalid_request_error'
        },
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIModelNotFoundError>()),
      );
    });

    test('500 → AIServerError', () async {
      final client = _mockResponse(500, {
        'error': {'message': 'Internal server error', 'type': 'server_error'},
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIServerError>()),
      );
    });

    test('token overflow → AITokenOverflowError', () async {
      final client = _mockResponse(400, {
        'error': {
          'message': 'This model maximum context length is 8192 tokens',
          'type': 'invalid_request_error',
        },
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AITokenOverflowError>()),
      );
    });
  });

  // ─── embed() ────────────────────────────────────────────────

  group('OpenAIProvider.embed()', () {
    test('parses embedding response', () async {
      final client = _mockResponse(200, {
        'data': [
          {
            'embedding': [0.1, 0.2, 0.3, 0.4],
            'index': 0,
          }
        ],
        'model': 'text-embedding-3-small',
        'usage': {'prompt_tokens': 5, 'total_tokens': 5},
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      final embedding = await provider.embed('Hello world');
      expect(embedding, [0.1, 0.2, 0.3, 0.4]);
    });

    test('embed error → throws AIError', () async {
      final client = _mockResponse(401, {
        'error': {'message': 'Invalid key', 'type': 'invalid_api_key'},
      });
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.embed('Hello'),
        throwsA(isA<AIAuthError>()),
      );
    });
  });

  // ─── Cost Estimation ────────────────────────────────────────

  group('OpenAIProvider cost estimation', () {
    test('returns cost for known models', () async {
      final client = _mockResponse(
          200,
          _completionResponse(
            promptTokens: 1000000,
            completionTokens: 1000000,
          ));
      final provider = OpenAIProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Hi')]);
      // gpt-4o: input $2.5/1M, output $10/1M → total $12.5
      expect(response.usage.estimatedCostUsd, closeTo(12.5, 0.01));
    });

    test('returns null cost for unknown models', () async {
      final unknownConfig =
          const AIConfig(apiKey: 'sk-test', model: 'unknown-model');
      final client = _mockResponse(200, _completionResponse());
      final provider =
          OpenAIProvider(config: unknownConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Hi')]);
      expect(response.usage.estimatedCostUsd, isNull);
    });
  });

  // ─── Metadata ───────────────────────────────────────────────

  group('OpenAIProvider metadata', () {
    test('name is OpenAI', () {
      final provider = OpenAIProvider(config: testConfig);
      expect(provider.name, 'OpenAI');
    });

    test('model matches config', () {
      final provider = OpenAIProvider(config: testConfig);
      expect(provider.model, 'gpt-4o');
    });

    test('supports expected capabilities', () {
      final provider = OpenAIProvider(config: testConfig);
      expect(provider.supports(AICapability.textCompletion), isTrue);
      expect(provider.supports(AICapability.streaming), isTrue);
      expect(provider.supports(AICapability.vision), isTrue);
      expect(provider.supports(AICapability.functionCalling), isTrue);
      expect(provider.supports(AICapability.embeddings), isTrue);
    });

    test('estimateTokens gives reasonable estimate', () {
      final provider = OpenAIProvider(config: testConfig);
      // "Hello world" = 11 chars → ~3 tokens
      expect(provider.estimateTokens('Hello world'), 3);
    });
  });
}
