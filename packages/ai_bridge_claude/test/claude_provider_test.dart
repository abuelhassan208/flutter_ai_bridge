import 'dart:convert';

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_claude/ai_bridge_claude.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testConfig =
      AIConfig(apiKey: 'sk-ant-test-key', model: 'claude-sonnet-4-20250514');

  MockClient _mockResponse(int statusCode, Map<String, dynamic> body) {
    return MockClient((request) async {
      return http.Response(jsonEncode(body), statusCode,
          headers: {'content-type': 'application/json'});
    });
  }

  // ─── Fixtures ───────────────────────────────────────────────

  Map<String, dynamic> _completionResponse({
    String text = 'Hello from Claude!',
    int inputTokens = 10,
    int outputTokens = 20,
    String? stopReason = 'end_turn',
  }) {
    return {
      'id': 'msg_test123',
      'type': 'message',
      'role': 'assistant',
      'model': 'claude-sonnet-4-20250514',
      'content': [
        {'type': 'text', 'text': text},
      ],
      'stop_reason': stopReason,
      'usage': {
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
      },
    };
  }

  // ─── complete() ─────────────────────────────────────────────

  group('ClaudeProvider.complete()', () {
    test('parses successful response correctly', () async {
      final client = _mockResponse(200, _completionResponse());
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      final response = await provider.complete([AIMessage.user('Hi')]);

      expect(response.content, 'Hello from Claude!');
      expect(response.provider, 'Claude');
      expect(response.model, 'claude-sonnet-4-20250514');
      expect(response.usage.promptTokens, 10);
      expect(response.usage.completionTokens, 20);
      expect(response.finishReason, 'end_turn');
    });

    test('sends x-api-key and anthropic-version headers', () async {
      late Map<String, String> capturedHeaders;
      final client = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedHeaders['x-api-key'], 'sk-ant-test-key');
      expect(capturedHeaders['anthropic-version'], '2023-06-01');
      expect(capturedHeaders['content-type'], 'application/json');
    });

    test('system prompt maps to top-level system field', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      await provider.complete([
        AIMessage.system('Be concise'),
        AIMessage.user('Hi'),
      ]);

      expect(capturedBody['system'], 'Be concise');
      // System message should NOT appear in messages array
      final messages = capturedBody['messages'] as List;
      expect(messages.length, 1);
      expect(messages.first['role'], 'user');
    });

    test('maps image bytes to base64 source block', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

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
      final content = messages.first['content'] as List;
      final imageBlock = content.firstWhere((c) => c['type'] == 'image');
      expect(imageBlock['source']['type'], 'base64');
      expect(imageBlock['source']['media_type'], 'image/png');
    });

    test('maps document bytes to base64 source block', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      await provider.complete([
        AIMessage(
          role: AIRole.user,
          content: 'Summarize this PDF',
          attachments: [
            AIAttachment(
              type: AIAttachmentType.document,
              bytes: [0x25, 0x50, 0x44, 0x46], // %PDF header
              mimeType: 'application/pdf',
            ),
          ],
        ),
      ]);

      final messages = capturedBody['messages'] as List;
      final content = messages.first['content'] as List;
      final docBlock = content.firstWhere((c) => c['type'] == 'document');
      expect(docBlock['source']['media_type'], 'application/pdf');
    });

    test('max_tokens defaults to 4096 when not specified', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_completionResponse()), 200,
            headers: {'content-type': 'application/json'});
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      await provider.complete([AIMessage.user('Hi')]);

      expect(capturedBody['max_tokens'], 4096);
    });
  });

  // ─── Error Mapping ──────────────────────────────────────────

  group('ClaudeProvider error mapping', () {
    test('401 → AIAuthError', () async {
      final client = _mockResponse(401, {
        'error': {'message': 'Invalid API key', 'type': 'authentication_error'},
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIAuthError>()),
      );
    });

    test('429 → AIRateLimitError', () async {
      final client = _mockResponse(429, {
        'error': {'message': 'Rate limit exceeded', 'type': 'rate_limit_error'},
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIRateLimitError>()),
      );
    });

    test('404 → AIModelNotFoundError', () async {
      final client = _mockResponse(404, {
        'error': {'message': 'Model not found', 'type': 'not_found_error'},
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIModelNotFoundError>()),
      );
    });

    test('500 → AIServerError', () async {
      final client = _mockResponse(500, {
        'error': {'message': 'Overloaded', 'type': 'overloaded_error'},
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AIServerError>()),
      );
    });

    test('token overflow → AITokenOverflowError', () async {
      final client = _mockResponse(400, {
        'error': {
          'message': 'max_tokens: 100000 > maximum allowed token count',
          'type': 'invalid_request_error',
        },
      });
      final provider = ClaudeProvider(config: testConfig, httpClient: client);

      expect(
        () => provider.complete([AIMessage.user('Hi')]),
        throwsA(isA<AITokenOverflowError>()),
      );
    });
  });

  // ─── embed() ────────────────────────────────────────────────

  group('ClaudeProvider.embed()', () {
    test('throws UnsupportedError', () {
      final provider = ClaudeProvider(config: testConfig);
      expect(
        () => provider.embed('Hello'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ─── Metadata ───────────────────────────────────────────────

  group('ClaudeProvider metadata', () {
    test('name is Claude', () {
      final provider = ClaudeProvider(config: testConfig);
      expect(provider.name, 'Claude');
    });

    test('does NOT support embeddings', () {
      final provider = ClaudeProvider(config: testConfig);
      expect(provider.supports(AICapability.embeddings), isFalse);
    });

    test('supports text, streaming, vision', () {
      final provider = ClaudeProvider(config: testConfig);
      expect(provider.supports(AICapability.textCompletion), isTrue);
      expect(provider.supports(AICapability.streaming), isTrue);
      expect(provider.supports(AICapability.vision), isTrue);
    });

    test('does NOT support function calling', () {
      final provider = ClaudeProvider(config: testConfig);
      expect(provider.supports(AICapability.functionCalling), isFalse);
    });
  });
}
