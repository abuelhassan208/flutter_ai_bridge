import 'package:test/test.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';

void main() {
  late _MockProvider mockProvider;

  setUp(() {
    mockProvider = _MockProvider();
  });

  group('ConversationManager', () {
    test('create makes a new conversation', () {
      final manager = ConversationManager(provider: mockProvider);
      final conv = manager.create(systemPrompt: 'Hello', title: 'Test');
      expect(conv.title, 'Test');
      expect(conv.messages.length, 1);
      expect(conv.systemMessage?.content, 'Hello');
    });

    test('get retrieves by ID', () {
      final manager = ConversationManager(provider: mockProvider);
      final conv = manager.create();
      expect(manager.get(conv.id), isNotNull);
      expect(manager.get('nonexistent'), isNull);
    });

    test('send adds user message and returns response', () async {
      final manager = ConversationManager(provider: mockProvider);
      final conv = manager.create();

      final response = await manager.send(conv.id, 'Hello');
      expect(response.content, contains('Mock'));
      // 1 system-less + user + assistant = 2 messages
      expect(conv.messages.length, 2);
    });

    test('send throws for unknown conversation', () {
      final manager = ConversationManager(provider: mockProvider);
      expect(
        () => manager.send('nonexistent', 'Hello'),
        throwsA(isA<StateError>()),
      );
    });

    test('delete removes conversation', () {
      final manager = ConversationManager(provider: mockProvider);
      final conv = manager.create();
      manager.delete(conv.id);
      expect(manager.get(conv.id), isNull);
    });

    test('all returns all conversations', () {
      final manager = ConversationManager(provider: mockProvider);
      manager.create(title: 'A');
      manager.create(title: 'B');
      expect(manager.all.length, 2);
    });

    test('clearAll removes all from memory', () {
      final manager = ConversationManager(provider: mockProvider);
      manager.create();
      manager.create();
      manager.clearAll();
      expect(manager.all, isEmpty);
    });
  });

  group('ToolExecutionLoop', () {
    test('returns response when no tool calls', () async {
      final loop = ToolExecutionLoop(provider: mockProvider);
      final conv = Conversation();
      conv.addMessage(AIMessage.user('Hello'));

      final response = await loop.execute(
        conversation: conv,
        contextMessages: conv.activeMessages,
      );

      expect(response.content, contains('Mock'));
    });

    test('executes tool calls and recurses', () async {
      int callCount = 0;
      final toolProvider = _ToolMockProvider(callsUntilDone: 2);
      final loop = ToolExecutionLoop(provider: toolProvider, maxIterations: 5);
      final conv = Conversation();
      conv.addMessage(AIMessage.user('Use tools'));

      final tools = [
        AITool(
          name: 'test_tool',
          description: 'A test tool',
          parameters: {},
          execute: (args) async {
            callCount++;
            return 'tool_result_$callCount';
          },
        ),
      ];

      final response = await loop.execute(
        conversation: conv,
        contextMessages: conv.activeMessages,
        tools: tools,
      );

      expect(callCount, 2); // Called twice before final response
      expect(response.content, contains('final'));
    });

    test('throws StateError when max iterations exceeded', () async {
      final infiniteProvider = _ToolMockProvider(callsUntilDone: 100);
      final loop =
          ToolExecutionLoop(provider: infiniteProvider, maxIterations: 3);
      final conv = Conversation();
      conv.addMessage(AIMessage.user('loop'));

      final tools = [
        AITool(
          name: 'test_tool',
          description: 'test',
          parameters: {},
          execute: (args) async => 'result',
        ),
      ];

      expect(
        () => loop.execute(
          conversation: conv,
          contextMessages: conv.activeMessages,
          tools: tools,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('handles missing tool gracefully', () async {
      final toolProvider = _ToolMockProvider(callsUntilDone: 1);
      final loop = ToolExecutionLoop(provider: toolProvider);
      final conv = Conversation();
      conv.addMessage(AIMessage.user('Call unknown'));

      // No tools provided — should add error message and recurse
      await loop.execute(
        conversation: conv,
        contextMessages: conv.activeMessages,
        tools: [], // empty tools list
      );

      // The loop should have added a tool result with error and then gotten final response
      final toolResultMsgs = conv.messages.where((m) => m.role == AIRole.tool);
      expect(toolResultMsgs.isNotEmpty, isTrue);
      expect(toolResultMsgs.first.content, contains('Error'));
    });
  });

  group('CancellationToken', () {
    test('starts not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel sets isCancelled to true', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled throws when cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(
          () => token.throwIfCancelled(), throwsA(isA<CancelledException>()));
    });

    test('throwIfCancelled does nothing when not cancelled', () {
      final token = CancellationToken();
      token.throwIfCancelled(); // Should not throw
    });

    test('cancel is idempotent', () {
      final token = CancellationToken();
      token.cancel();
      token.cancel(); // Should not throw
      expect(token.isCancelled, isTrue);
    });
  });
}

/// Simple mock provider that returns non-tool responses.
class _MockProvider implements AIProvider {
  @override
  String get name => 'Mock';
  @override
  String get model => 'mock-1';
  @override
  AIConfig get config => AIConfig(apiKey: 'test', model: 'mock-1');
  @override
  List<AICapability> get capabilities => [AICapability.textCompletion];
  @override
  bool supports(AICapability c) => capabilities.contains(c);

  @override
  Future<AIResponse> complete(List<AIMessage> messages,
      {int? maxTokens, double? temperature, List<AITool>? tools}) async {
    return AIResponse(
      content: 'Mock response',
      usage: const AIUsage(promptTokens: 10, completionTokens: 5),
      model: model,
      provider: name,
      latency: const Duration(milliseconds: 10),
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(List<AIMessage> messages,
      {int? maxTokens, double? temperature, List<AITool>? tools}) async* {
    yield const AIStreamChunk(text: 'Mock', isComplete: true);
  }

  @override
  Future<List<double>> embed(String text) async => [0.0];
  @override
  int estimateTokens(String text) => (text.length / 4).ceil();
  @override
  Future<void> dispose() async {}
}

/// Mock provider that returns tool calls for [callsUntilDone] times,
/// then returns a final text response.
class _ToolMockProvider implements AIProvider {
  int _callCount = 0;
  final int callsUntilDone;

  _ToolMockProvider({this.callsUntilDone = 1});

  @override
  String get name => 'ToolMock';
  @override
  String get model => 'tool-mock-1';
  @override
  AIConfig get config => AIConfig(apiKey: 'test', model: 'tool-mock-1');
  @override
  List<AICapability> get capabilities =>
      [AICapability.textCompletion, AICapability.functionCalling];
  @override
  bool supports(AICapability c) => capabilities.contains(c);

  @override
  Future<AIResponse> complete(List<AIMessage> messages,
      {int? maxTokens, double? temperature, List<AITool>? tools}) async {
    _callCount++;
    if (_callCount <= callsUntilDone) {
      return AIResponse(
        content: '',
        usage: const AIUsage(promptTokens: 5, completionTokens: 3),
        model: model,
        provider: name,
        latency: const Duration(milliseconds: 5),
        toolCalls: [
          AIToolCall(
              id: 'tc_$_callCount',
              name: 'test_tool',
              arguments: {'step': _callCount}),
        ],
      );
    }
    return AIResponse(
      content: 'final response after $_callCount calls',
      usage: const AIUsage(promptTokens: 5, completionTokens: 10),
      model: model,
      provider: name,
      latency: const Duration(milliseconds: 5),
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(List<AIMessage> messages,
      {int? maxTokens, double? temperature, List<AITool>? tools}) async* {
    yield const AIStreamChunk(text: 'mock', isComplete: true);
  }

  @override
  Future<List<double>> embed(String text) async => [0.0];
  @override
  int estimateTokens(String text) => (text.length / 4).ceil();
  @override
  Future<void> dispose() async {}
}
