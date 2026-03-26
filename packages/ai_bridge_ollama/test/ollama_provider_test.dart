import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testConfig = AIConfig(apiKey: '', model: 'llama3.2');

  MockClient mockResponse(int statusCode, Map<String, dynamic> body) {
    return MockClient((request) async {
      return http.Response(jsonEncode(body), statusCode,
          headers: {'content-type': 'application/json'});
    });
  }

  // ─── Fixtures ───────────────────────────────────────────────

  Map<String, dynamic> chatResponse({
    String content = 'Hello from Ollama!',
    int promptEvalCount = 15,
    int evalCount = 25,
  }) {
    return {
      'model': 'llama3.2',
      'created_at': '2026-01-01T00:00:00Z',
      'message': {
        'role': 'assistant',
        'content': content,
      },
      'done': true,
      'prompt_eval_count': promptEvalCount,
      'eval_count': evalCount,
    };
  }

  // ─── complete() ─────────────────────────────────────────────

  group('OllamaProvider.complete()', () {
    test('parses successful response correctly', () async {
      final client = mockResponse(200, chatResponse());
      final provider = OllamaProvider(config: testConfig, client: client);

      final response = await provider.complete([AIMessage.user('Hi')]);

      expect(response.content, 'Hello from Ollama!');
      expect(response.provider, 'Ollama');
      expect(response.model, 'llama3.2');
      expect(response.usage.promptTokens, 15);
      expect(response.usage.completionTokens, 25);
      expect(response.usage.totalTokens, 40);
    });

    test('sends correct request body', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(chatResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedBody['model'], 'llama3.2');
      expect(capturedBody['stream'], false);
      expect(capturedBody['messages'], isNotEmpty);
    });

    test('posts to correct URL', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(chatResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedUri.toString(), 'http://localhost:11434/api/chat');
    });

    test('custom baseUrl is used', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(chatResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OllamaProvider(
        config: testConfig,
        client: client,
        baseUrl: 'http://10.0.2.2:11434',
      );

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedUri.host, '10.0.2.2');
    });

    test('maps image attachments to images array', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(chatResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      await provider.complete([
        AIMessage(
          role: AIRole.user,
          content: 'What is this?',
          attachments: [
            AIAttachment.imageBytes([1, 2, 3])
          ],
        ),
      ]);

      final messages = capturedBody['messages'] as List;
      final userMsg = messages.last as Map<String, dynamic>;
      expect(userMsg['images'], isNotNull);
      expect((userMsg['images'] as List).length, 1);
    });

    test('wraps non-AIError in AINetworkError', () async {
      final client = MockClient((request) async {
        throw Exception('Connection refused');
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AINetworkError>()),
      );
    });
  });

  // ─── Error Mapping ──────────────────────────────────────────

  group('OllamaProvider error mapping', () {
    test('404 → AIModelNotFoundError', () async {
      final client = mockResponse(404, {'error': 'model not found'});
      final provider = OllamaProvider(config: testConfig, client: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIModelNotFoundError>()),
      );
    });

    test('500 → AIServerError', () async {
      final client = mockResponse(500, {'error': 'internal error'});
      final provider = OllamaProvider(config: testConfig, client: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIServerError>()),
      );
    });
  });

  // ─── embed() ────────────────────────────────────────────────

  group('OllamaProvider.embed()', () {
    test('parses embedding key (older API)', () async {
      final client = mockResponse(200, {
        'embedding': [0.1, 0.2, 0.3],
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      final embedding = await provider.embed('Hello');
      expect(embedding, [0.1, 0.2, 0.3]);
    });

    test('parses embeddings key (newer API)', () async {
      final client = mockResponse(200, {
        'embeddings': [
          [0.4, 0.5, 0.6]
        ],
      });
      final provider = OllamaProvider(config: testConfig, client: client);

      final embedding = await provider.embed('Hello');
      expect(embedding, [0.4, 0.5, 0.6]);
    });

    test('returns empty list when no embedding key', () async {
      final client = mockResponse(200, {'model': 'test'});
      final provider = OllamaProvider(config: testConfig, client: client);

      final embedding = await provider.embed('Hello');
      expect(embedding, isEmpty);
    });
  });

  // ─── Metadata ───────────────────────────────────────────────

  group('OllamaProvider metadata', () {
    test('name is Ollama', () {
      final provider = OllamaProvider(config: testConfig);
      expect(provider.name, 'Ollama');
    });

    test('model matches config', () {
      final provider = OllamaProvider(config: testConfig);
      expect(provider.model, 'llama3.2');
    });

    test('supports expected capabilities', () {
      final provider = OllamaProvider(config: testConfig);
      expect(provider.supports(AICapability.textCompletion), isTrue);
      expect(provider.supports(AICapability.streaming), isTrue);
      expect(provider.supports(AICapability.embeddings), isTrue);
      expect(provider.supports(AICapability.vision), isTrue);
      expect(provider.supports(AICapability.functionCalling), isFalse);
    });
  });
}
