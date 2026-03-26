/// Comprehensive usage examples for `ai_bridge_core`.
///
/// This file demonstrates every major feature of the core framework:
/// - AIRouter with multi-provider fallback
/// - ConversationalAgent with tools
/// - AIPipeline (sequential multi-agent orchestration)
/// - RAG (DocumentChunker + InMemoryVectorStore)
/// - Observability (ConsoleAILogger)
/// - Cost Control (TokenBudget + ResponseCache)
/// - Output Parsers (JsonOutputParser + RetryOutputParser)
///
/// Note: This is a pure-Dart example. For a full Flutter UI demo,
/// see the `flutter_ai_bridge/example` app.
library;

import 'package:ai_bridge_core/ai_bridge_core.dart';

// ─────────────────────────────────────────────
// 1. AIRouter — Multi-Provider Routing
// ─────────────────────────────────────────────
/// The AIRouter manages multiple providers and selects the best one
/// based on a configurable routing strategy.
void routerExample(List<AIProvider> providers) async {
  // Route by cost
  final costRouter = AIRouter(
    providers: providers,
    strategy: RoutingStrategy.costOptimized,
  );
  final cheapest = await costRouter.route([AIMessage.user('Hello')]);
  print('Cheapest provider answer from: ${cheapest.provider}');

  // Route by latency
  final latencyRouter = AIRouter(
    providers: providers,
    strategy: RoutingStrategy.latencyOptimized,
  );
  final fastest = await latencyRouter.route([AIMessage.user('Hello')]);
  print('Fastest provider answer from: ${fastest.provider}');

  // Fallback chain — tries providers in order until one succeeds
  final chain = FallbackChain(providers: providers, circuitBreakers: {});
  print('Fallback chain ready with ${chain.providers.length} providers.');
}

// ─────────────────────────────────────────────
// 2. ConversationalAgent — Autonomous Agent
// ─────────────────────────────────────────────
/// A ConversationalAgent wraps a provider with a system prompt, tools,
/// and automatic memory management via AgentContext.
Future<void> agentExample(AIProvider provider) async {
  // Define a tool the agent can call
  final weatherTool = AITool(
    name: 'get_weather',
    description: 'Get current weather for a city',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'City name'},
      },
      'required': ['city'],
    },
    execute: (args) async => '{"temp": 22, "condition": "Sunny"}',
  );

  // Create the agent
  final agent = ConversationalAgent(
    name: 'WeatherBot',
    systemPrompt: 'You are a helpful weather assistant.',
    provider: provider,
    tools: [weatherTool],
  );

  // Execute with shared context
  final context = AgentContext(logger: ConsoleAILogger());
  await agent.execute(context, taskInput: 'What is the weather in Cairo?');

  // The context now contains the full conversation history
  print('Messages: ${context.conversation.activeMessages.length}');
}

// ─────────────────────────────────────────────
// 3. AIPipeline — Sequential Multi-Agent Flow
// ─────────────────────────────────────────────
/// AIPipeline chains multiple agents together, passing a shared
/// AgentContext through each step sequentially.
Future<void> pipelineExample(
    AIProvider writerProvider, AIProvider reviewerProvider) async {
  final writer = ConversationalAgent(
    name: 'ContentWriter',
    systemPrompt: 'You are a blog post writer. Write engaging content.',
    provider: writerProvider,
  );

  final reviewer = ConversationalAgent(
    name: 'Editor',
    systemPrompt:
        'You are a content editor. Review and improve the given text.',
    provider: reviewerProvider,
  );

  // Pipeline: Writer → Editor
  final pipeline = AIPipeline(
    sequence: [
      AgentTask(
        description: 'Write a blog post about Flutter AI integration.',
        assignee: writer,
      ),
      AgentTask(
        description:
            'Review the blog post above. Suggest improvements and fix errors.',
        assignee: reviewer,
      ),
    ],
  );

  final result = await pipeline.execute();
  print('Pipeline complete. Variables: ${result.variables}');
}

// ─────────────────────────────────────────────
// 4. RAG — Retrieval-Augmented Generation
// ─────────────────────────────────────────────
/// DocumentChunker + InMemoryVectorStore for local semantic search.
Future<void> ragExample(AIEmbeddingProvider embedder) async {
  // 1. Chunk a long document
  final chunker = DocumentChunker(chunkSize: 500, chunkOverlap: 100);
  final docs = chunker.splitText(
    'Flutter is an open source framework by Google for building '
    'beautiful, natively compiled, multi-platform applications from '
    'a single codebase. It supports iOS, Android, web, and desktop. '
    'Flutter uses the Dart programming language and features a rich '
    'set of pre-designed widgets for Material Design and Cupertino.',
    metadata: {'source': 'flutter_docs'},
  );
  print('Created ${docs.length} chunks.');

  // 2. Store in a vector database
  final vectorStore = InMemoryVectorStore(embedder: embedder);
  await vectorStore.addDocuments(docs);

  // 3. Semantic search
  final results =
      await vectorStore.similaritySearch('mobile development', limit: 2);
  for (final r in results) {
    print('Match: ${r.content.substring(0, 50)}...');
  }
}

// ─────────────────────────────────────────────
// 5. Observability — Logging & Telemetry
// ─────────────────────────────────────────────
/// ConsoleAILogger provides structured logging for agents, tools,
/// token usage, and errors.
void observabilityExample() {
  final logger = ConsoleAILogger(enableDebugLogging: true);

  // Trace messages
  logger.logTrace('Starting AI pipeline', data: {'step': 1});

  // Agent lifecycle
  logger.logAgentStart('ResearchBot', 'task-001');
  logger.logAgentEnd('ResearchBot', 'task-001',
      success: true, duration: Duration(milliseconds: 1200));

  // Tool calls
  logger.logToolCall('search_web', {'query': 'Flutter AI'});
  logger.logToolResult('search_web', 'Found 10 results...');

  // Token usage
  logger.logTokenUsage('openai', 'gpt-4o',
      promptTokens: 150,
      completionTokens: 300,
      latency: Duration(milliseconds: 800));
}

// ─────────────────────────────────────────────
// 6. Cost Control — Budget & Caching
// ─────────────────────────────────────────────
/// TokenBudget enforces spending limits per request, session, and day.
/// ResponseCache avoids duplicate API calls for identical prompts.
void costControlExample() {
  // Set up a budget: max 1000 tokens/request, 10000/session, 50000/day
  final budget = TokenBudget(
    maxTokensPerRequest: 1000,
    maxTokensPerSession: 10000,
    maxTokensPerDay: 50000,
  );

  // Check before sending
  if (budget.canProceed(500)) {
    print('✅ Within budget. Proceeding...');
    // After response, record usage
    budget.recordUsage(AIUsage(promptTokens: 200, completionTokens: 300));
  }

  print('Session used: ${budget.sessionTokensUsed} tokens');
  print('Daily remaining: ${budget.dailyRemaining} tokens');

  final cache = ResponseCache();
  cache.put(
      'What is Flutter?',
      AIResponse(
          content: 'Flutter is a UI toolkit...',
          usage: AIUsage.zero,
          model: 'cache',
          provider: 'cache',
          latency: Duration.zero));
  final cached = cache.get('What is Flutter?');
  print('Cache hit: ${cached != null}');
}

// ─────────────────────────────────────────────
// 7. Output Parsers — Structured Extraction
// ─────────────────────────────────────────────
/// JsonOutputParser extracts JSON from LLM text.
/// RetryOutputParser automatically re-prompts the LLM on parse failures.
Future<void> parserExample(AICompletionProvider provider) async {
  // Basic JSON parsing
  final parser = JsonOutputParser();
  final result = parser.parse('{"name": "Ali", "age": 25}');
  print('Parsed: $result');

  // With automatic retry on failure
  final retryParser = RetryOutputParser(
    parser: parser,
    provider: provider,
    maxRetries: 3,
    logger: ConsoleAILogger(),
  );

  final context = [AIMessage.user('Give me a JSON object with name and age.')];
  final parsed = await retryParser.parseWithRetry(
    '{"name": "Ali", "age": 25}',
    context,
  );
  print('Retry-parsed: $parsed');
}

// ─────────────────────────────────────────────
// 8. Streaming — Real-Time Token Output
// ─────────────────────────────────────────────
/// StreamHandler provides utilities for accumulating and processing
/// streaming AI responses token by token.
Future<void> streamingExample(AIStreamingProvider provider) async {
  final handler = StreamHandler();
  final messages = [AIMessage.user('Tell me about Dart.')];

  // Stream tokens in real-time
  final stream = provider.completeStream(messages);

  // Accumulate the full response
  final fullText = await handler.process(stream);
  print('Full response: $fullText');
}

// ─────────────────────────────────────────────
// Main — Run Examples
// ─────────────────────────────────────────────
void main() {
  print('═══════════════════════════════════════════════');
  print('  Flutter AI Bridge — Core Examples');
  print('═══════════════════════════════════════════════');
  print('');
  print('This file demonstrates the API surface of ai_bridge_core.');
  print('To run real examples, add a provider package like:');
  print('  - ai_bridge_openai');
  print('  - ai_bridge_gemini');
  print('  - ai_bridge_claude');
  print('  - ai_bridge_ollama');
  print('');

  // Run synchronous examples
  observabilityExample();
  costControlExample();

  print('');
  print('See each function above for complete async examples.');
  print('For a full Flutter app demo: flutter_ai_bridge/example/');
}
