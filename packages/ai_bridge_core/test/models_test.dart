import 'package:test/test.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';

void main() {
  group('AIMessage', () {
    test('factory constructors create correct roles', () {
      final system = AIMessage.system('Be helpful');
      expect(system.role, AIRole.system);
      expect(system.content, 'Be helpful');

      final user = AIMessage.user('Hello');
      expect(user.role, AIRole.user);

      final assistant = AIMessage.assistant('Hi there');
      expect(assistant.role, AIRole.assistant);

      final toolResult = AIMessage.toolResult('tc_1', 'result data');
      expect(toolResult.role, AIRole.tool);
      expect(toolResult.toolCallId, 'tc_1');
    });

    test('IDs are unique', () {
      final a = AIMessage.user('a');
      final b = AIMessage.user('b');
      expect(a.id, isNot(equals(b.id)));
    });

    test('copyWith preserves ID and timestamp', () {
      final original = AIMessage.user('Hello');
      final copy = original.copyWith(content: 'Modified');
      expect(copy.id, equals(original.id));
      expect(copy.timestamp, equals(original.timestamp));
      expect(copy.content, 'Modified');
    });

    test('toJson / fromJson round-trip', () {
      final original = AIMessage(
        role: AIRole.user,
        content: 'Test message',
        attachments: [
          AIAttachment.imageUrl('https://example.com/img.png'),
        ],
      );

      final json = original.toJson();
      final restored = AIMessage.fromJson(json);

      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.id, original.id);
      expect(restored.timestamp, original.timestamp);
      expect(restored.attachments, isNotNull);
      expect(restored.attachments!.length, 1);
      expect(restored.attachments!.first.url, 'https://example.com/img.png');
    });

    test('tool calls round-trip through JSON', () {
      final original = AIMessage.assistant(
        'Let me call a tool',
        toolCalls: [
          AIToolCall(
              id: 'tc_1', name: 'get_weather', arguments: {'city': 'Cairo'}),
        ],
      );

      final json = original.toJson();
      final restored = AIMessage.fromJson(json);

      expect(restored.toolCalls, isNotNull);
      expect(restored.toolCalls!.first.id, 'tc_1');
      expect(restored.toolCalls!.first.name, 'get_weather');
      expect(restored.toolCalls!.first.arguments['city'], 'Cairo');
    });

    test('toString truncates long content', () {
      final longMsg = AIMessage.user('A' * 100);
      expect(longMsg.toString(), contains('...'));
    });
  });

  group('AIAttachment', () {
    test('assert requires at least one data source', () {
      expect(
        () => AIAttachment(type: AIAttachmentType.image),
        throwsA(isA<AssertionError>()),
      );
    });

    test('factory constructors', () {
      final imgUrl = AIAttachment.imageUrl('https://example.com/img.png');
      expect(imgUrl.type, AIAttachmentType.image);
      expect(imgUrl.url, 'https://example.com/img.png');

      final imgBytes = AIAttachment.imageBytes([1, 2, 3]);
      expect(imgBytes.bytes, [1, 2, 3]);
      expect(imgBytes.mimeType, 'image/png');
    });

    test('toJson / fromJson round-trip', () {
      final original = AIAttachment(
        type: AIAttachmentType.document,
        url: 'https://example.com/doc.pdf',
        mimeType: 'application/pdf',
        name: 'report.pdf',
      );

      final json = original.toJson();
      final restored = AIAttachment.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.url, original.url);
      expect(restored.mimeType, original.mimeType);
      expect(restored.name, original.name);
    });
  });

  group('AIUsage', () {
    test('totalTokens is sum of prompt + completion', () {
      const usage = AIUsage(promptTokens: 100, completionTokens: 50);
      expect(usage.totalTokens, 150);
    });

    test('operator + adds correctly', () {
      const a = AIUsage(
          promptTokens: 10, completionTokens: 5, estimatedCostUsd: 0.01);
      const b = AIUsage(
          promptTokens: 20, completionTokens: 10, estimatedCostUsd: 0.02);
      final sum = a + b;
      expect(sum.promptTokens, 30);
      expect(sum.completionTokens, 15);
      expect(sum.estimatedCostUsd, closeTo(0.03, 0.001));
    });

    test('zero constant', () {
      expect(AIUsage.zero.totalTokens, 0);
    });
  });

  group('Conversation', () {
    test('addMessage updates updatedAt', () {
      final conv = Conversation(title: 'Test');
      final before = conv.updatedAt;
      // Small delay to ensure different timestamp
      conv.addMessage(AIMessage.user('Hello'));
      expect(conv.messages.length, 1);
      expect(conv.updatedAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch));
    });

    test('systemMessage returns last system message', () {
      final conv = Conversation();
      conv.addMessage(AIMessage.system('V1'));
      conv.addMessage(AIMessage.system('V2'));
      expect(conv.systemMessage?.content, 'V2');
    });

    test('isEmpty ignores system messages', () {
      final conv = Conversation();
      conv.addMessage(AIMessage.system('System'));
      expect(conv.isEmpty, isTrue);
      conv.addMessage(AIMessage.user('Hello'));
      expect(conv.isEmpty, isFalse);
    });

    test('toJson / fromJson round-trip', () {
      final conv = Conversation(title: 'Chat');
      conv.addMessage(AIMessage.system('Be helpful'));
      conv.addMessage(AIMessage.user('Hello'));

      final json = conv.toJson();
      final restored = Conversation.fromJson(json);

      expect(restored.id, conv.id);
      expect(restored.title, 'Chat');
      expect(restored.messages.length, 2);
      expect(restored.messages.first.role, AIRole.system);
    });
  });
}
