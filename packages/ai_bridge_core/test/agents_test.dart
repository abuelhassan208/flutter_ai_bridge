import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:test/test.dart';

/// A simple mock provider that intercepts completions and returns a pre-configured response.
class MockAgentProvider implements AIProvider {
  @override
  final String name = 'mock';

  @override
  String get model => 'mock-model';

  @override
  AIConfig get config => const AIConfig(apiKey: 'test', model: 'mock-model');

  @override
  List<AICapability> get capabilities => const [AICapability.textCompletion];

  final String Function(String prompt)? customResponseBuilder;
  final String defaultResponse;

  MockAgentProvider(
      {this.defaultResponse = 'success', this.customResponseBuilder});

  @override
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async {
    final prompt = messages.last.content;
    final r = customResponseBuilder != null
        ? customResponseBuilder!(prompt)
        : defaultResponse;
    return AIResponse(
      content: r,
      usage: const AIUsage(promptTokens: 10, completionTokens: 10),
      model: model,
      provider: name,
      latency: const Duration(milliseconds: 50),
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) async* {
    yield AIStreamChunk(text: defaultResponse, isComplete: true);
  }

  @override
  Future<List<double>> embed(String text) async {
    return [0.1, 0.2];
  }

  @override
  int estimateTokens(String text) => (text.length / 4).ceil();

  @override
  bool supports(AICapability capability) => capabilities.contains(capability);

  @override
  Future<void> dispose() async {}
}

void main() {
  group('AIAgent and Pipelines', () {
    test('ConversationalAgent executes and updates AgentContext', () async {
      final mock = MockAgentProvider(
          defaultResponse: 'I am a poetry agent. Here is a poem.');
      final context = AgentContext();

      final agent = ConversationalAgent(
        name: 'Poet',
        systemPrompt: 'You write poems.',
        provider: mock,
      );

      await agent.execute(context, taskInput: 'Write a poem about the sun.');

      // Context should contain the conversation history.
      final history = context.conversation.messages;
      expect(history.length, 3); // system, user, assistant
      expect(history[0].role, AIRole.system);
      expect(history[1].content, 'Write a poem about the sun.');
      expect(history[2].content, 'I am a poetry agent. Here is a poem.');
    });

    test('AIPipeline runs sequentially and shares context', () async {
      final writerMock = MockAgentProvider(defaultResponse: 'Article body.');
      final editorMock =
          MockAgentProvider(defaultResponse: 'Edited article body.');

      final writer = ConversationalAgent(
        name: 'Writer',
        systemPrompt: 'You write rough drafts.',
        provider: writerMock,
        outputParser: (res, ctx) => ctx.write('draft', res),
      );

      final editor = ConversationalAgent(
        name: 'Editor',
        systemPrompt: 'You edit drafts.',
        provider: editorMock,
        outputParser: (res, ctx) => ctx.write('final_copy', res),
      );

      final pipeline = AIPipeline(sequence: [
        AgentTask(description: 'Write an article.', assignee: writer),
        AgentTask(description: 'Edit the drafted article.', assignee: editor),
      ]);

      final context = await pipeline.execute();

      expect(context.read('draft'), 'Article body.');
      expect(context.read('final_copy'), 'Edited article body.');
      expect(context.conversation.messages.length,
          6); // 2 tasks = 2 x (system, user, assistant)
    });

    test('ParallelPipeline runs concurrently', () async {
      final imgMock = MockAgentProvider(defaultResponse: 'Image generated.');
      final audioMock = MockAgentProvider(defaultResponse: 'Audio generated.');

      final imgAgent = ConversationalAgent(
        name: 'Visuals',
        systemPrompt: '',
        provider: imgMock,
        outputParser: (res, ctx) => ctx.write('image', res),
      );

      final audioAgent = ConversationalAgent(
        name: 'Audio',
        systemPrompt: '',
        provider: audioMock,
        outputParser: (res, ctx) => ctx.write('audio', res),
      );

      final parallel = ParallelPipeline(tasks: [
        AgentTask(description: 'Make picture.', assignee: imgAgent),
        AgentTask(description: 'Make sound.', assignee: audioAgent),
      ]);

      final context = await parallel.execute();
      expect(context.read('image'), 'Image generated.');
      expect(context.read('audio'), 'Audio generated.');
    });

    test('SupervisorAgent routes intelligently based on LLM response',
        () async {
      // Mock supervisor JSON response that selects "BackendDev"
      final supervisorMock = MockAgentProvider(
          defaultResponse:
              '{"selected_agent": "BackendDev", "adjusted_task": "Write Nodejs API"}');
      final backendMock =
          MockAgentProvider(defaultResponse: 'Express router created.');
      final frontendMock =
          MockAgentProvider(defaultResponse: 'React component created.');

      final backendDev = ConversationalAgent(
          name: 'BackendDev', systemPrompt: 'Node dev', provider: backendMock);
      final frontendDev = ConversationalAgent(
          name: 'FrontendDev',
          systemPrompt: 'React dev',
          provider: frontendMock);

      final supervisor = SupervisorAgent(
        name: 'TechLead',
        provider: supervisorMock,
        subAgents: [backendDev, frontendDev],
      );

      final context = AgentContext();
      await supervisor.execute(context,
          taskInput: 'Create an API endpoint for users.');

      expect(context.read('supervisor_decision'), 'BackendDev');

      // Since it chose BackendDev, the active conversation should contain backendDev's responses
      expect(context.conversation.messages.last.content,
          'Express router created.');
    });
  });
}
