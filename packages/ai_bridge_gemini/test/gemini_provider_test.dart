import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testConfig =
      AIConfig(apiKey: 'AIza-test-key', model: 'gemini-2.0-flash');

  MockClient _mockResponse(int statusCode, Map<String, dynamic> body) {
    return MockClient((request) async {
      return http.Response(jsonEncode(body), statusCode,
          headers: {'content-type': 'application/json'});
    });
  }

  // ─── Fixtures ───────────────────────────────────────────────

  Map<String, dynamic> _completionResponse({
    String text = 'Hello from Gemini!',
    int promptTokens = 10,
    int completionTokens = 20,
    String? finishReason = 'STOP',
    List<Map<String, dynamic>>? functionCalls,
  }) {
    final parts = <Map<String, dynamic>>[];
    if (text.isNotEmpty) parts.add({'text': text});
    if (functionCalls != null) {
      for (final fc in functionCalls) {
        parts.add({'functionCall': fc});
      }
    }

    return {
      'candidates': [
        {
          'content': {'role': 'model', 'parts': parts},
          'finishReason': finishReason,
        }
      ],
      'usageMetadata': {
        'promptTokenCount': promptTokens,
        'candidatesTokenCount': completionTokens,
        'totalTokenCount': promptTokens + completionTokens,
      },
    };
  }

  // ─── complete() ─────────────────────────────────────────────

  group('GeminiProvider.complete()', () {
    test('parses successful response correctly', () async {
      final client = _mockResponse(200, _completionResponse());
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Hi')]);

      expect(response.content, 'Hello from Gemini!');
      expect(response.provider, 'Gemini');
      expect(response.model, 'gemini-2.0-flash');
      expect(response.usage.promptTokens, 10);
      expect(response.usage.completionTokens, 20);
      expect(response.finishReason, 'STOP');
    });

    test('parses function calls in response', () async {
      final fixture = _completionResponse(
        text: '',
        functionCalls: [
          {
            'name': 'get_weather',
            'args': {'city': 'Cairo'},
          }
        ],
      );
      final client = _mockResponse(200, fixture);
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Weather?')]);

      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.name, 'get_weather');
      expect(response.toolCalls!.first.arguments['city'], 'Cairo');
    });

    test('sends API key as query parameter', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedUri.queryParameters['key'], 'AIza-test-key');
      expect(capturedUri.path, contains('gemini-2.0-flash:generateContent'));
    });

    test('system prompt maps to systemInstruction', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      await provider.complete([
        AIMessage.system('Be helpful'),
        AIMessage.user('Hi'),
      ]);

      expect(capturedBody['systemInstruction'], isNotNull);
      final instruction =
          capturedBody['systemInstruction'] as Map<String, dynamic>;
      final parts = instruction['parts'] as List;
      expect((parts.first as Map)['text'], 'Be helpful');

      // System message should NOT appear in contents
      final contents = capturedBody['contents'] as List;
      expect(contents.length, 1); // only user message
    });

    test('tool response maps to functionResponse in user role', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      await provider.complete([
        AIMessage.user('Weather?'),
        AIMessage.assistant('', toolCalls: [
          AIToolCall(
              id: 'get_weather',
              name: 'get_weather',
              arguments: {'city': 'Cairo'}),
        ]),
        AIMessage.toolResult('get_weather', '25°C sunny'),
      ]);

      final contents = capturedBody['contents'] as List;
      // Find the functionResponse
      final toolMsg = contents.firstWhere(
        (c) => (c['parts'] as List).any(
          (p) => (p as Map).containsKey('functionResponse'),
        ),
      );
      expect(
          toolMsg['role'], 'user'); // Gemini expects tool responses from user
    });

    test('throws AIContentFilterError on empty candidates', () async {
      final client = _mockResponse(200, {'candidates': []});
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIContentFilterError>()),
      );
    });
  });

  // ─── Error Mapping ──────────────────────────────────────────

  group('GeminiProvider error mapping', () {
    test('403 → AIAuthError', () async {
      final client = _mockResponse(403, {
        'error': {'message': 'Permission denied'},
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIAuthError>()),
      );
    });

    test('429 → AIRateLimitError', () async {
      final client = _mockResponse(429, {
        'error': {'message': 'Quota exceeded'},
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIRateLimitError>()),
      );
    });

    test('404 → AIModelNotFoundError', () async {
      final client = _mockResponse(404, {
        'error': {'message': 'Model not found'},
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIModelNotFoundError>()),
      );
    });

    test('500 → AIServerError', () async {
      final client = _mockResponse(500, {
        'error': {'message': 'Internal error'},
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIServerError>()),
      );
    });

    test('400 with API key message → AIAuthError', () async {
      final client = _mockResponse(400, {
        'error': {'message': 'API key not valid'},
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIAuthError>()),
      );
    });
  });

  // ─── embed() ────────────────────────────────────────────────

  group('GeminiProvider.embed()', () {
    test('parses embedding response', () async {
      final client = _mockResponse(200, {
        'embedding': {
          'values': [0.1, 0.2, 0.3],
        },
      });
      final provider = GeminiProvider(config: testConfig, httpClient: client);

      final embedding = await provider.embed('Hello');
      expect(embedding, [0.1, 0.2, 0.3]);
    });
  });

  // ─── Metadata ───────────────────────────────────────────────

  group('GeminiProvider metadata', () {
    test('name is Gemini', () {
      final provider = GeminiProvider(config: testConfig);
      expect(provider.name, 'Gemini');
    });

    test('supports expected capabilities', () {
      final provider = GeminiProvider(config: testConfig);
      expect(provider.supports(AICapability.textCompletion), isTrue);
      expect(provider.supports(AICapability.streaming), isTrue);
      expect(provider.supports(AICapability.vision), isTrue);
      expect(provider.supports(AICapability.functionCalling), isTrue);
      expect(provider.supports(AICapability.embeddings), isTrue);
    });
  });
}
