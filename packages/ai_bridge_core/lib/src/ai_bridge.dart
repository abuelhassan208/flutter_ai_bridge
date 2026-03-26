import 'models/ai_message.dart';
import 'models/ai_response.dart';
import 'models/ai_tool.dart';
import 'conversation/conversation_manager.dart';
import 'conversation/token_tracker.dart';
import 'cost/response_cache.dart';
import 'cost/token_budget.dart';
import 'errors/retry_handler.dart';
import 'providers/ai_provider.dart';
import 'router/ai_router.dart';

/// The main entry point for Flutter AI Bridge.
///
/// [AIBridge] ties together providers, routing, conversation management,
/// cost control, and caching into a single, easy-to-use API.
///
/// ```dart
/// final bridge = AIBridge(
///   providers: [
///     OpenAIProvider(config: AIConfig(apiKey: 'sk-...', model: 'gpt-4o')),
///     GeminiProvider(config: AIConfig(apiKey: 'AI...', model: 'gemini-2.0-flash')),
///   ],
///   strategy: RoutingStrategy.costOptimized,
///   budget: TokenBudget(maxTokensPerDay: 100000),
/// );
///
/// final response = await bridge.complete('Hello, AI!');
/// ```
class AIBridge {
  /// The smart router handling provider selection.
  final AIRouter router;

  /// Optional token budget for cost control.
  final TokenBudget? budget;

  /// Optional response cache.
  final ResponseCache? cache;

  /// Retry handler for transient failures.
  final RetryHandler retryHandler;

  /// Token usage tracker.
  final TokenTracker tokenTracker = TokenTracker();

  /// Active conversation managers (keyed by provider name).
  final Map<String, ConversationManager> _conversationManagers = {};

  AIBridge({
    required List<AIProvider> providers,
    RoutingStrategy strategy = RoutingStrategy.primary,
    this.budget,
    this.cache,
    RetryHandler? retryHandler,
  })  : router = AIRouter(providers: providers, strategy: strategy),
        retryHandler = retryHandler ?? RetryHandler();

  /// The list of registered providers.
  List<AIProvider> get providers => router.providers;

  /// The primary (first) provider.
  AIProvider get primaryProvider => router.providers.first;

  /// Sends a simple text completion request.
  ///
  /// Optionally uses caching and budget enforcement.
  Future<AIResponse> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
    bool useCache = false,
    List<AITool>? tools,
  }) async {
    final messages = <AIMessage>[
      if (systemPrompt != null) AIMessage.system(systemPrompt),
      AIMessage.user(prompt),
    ];

    return completeMessages(
      messages,
      maxTokens: maxTokens,
      temperature: temperature,
      useCache: useCache,
      tools: tools,
    );
  }

  /// Sends a completion request with full message history.
  Future<AIResponse> completeMessages(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    bool useCache = false,
    List<AITool>? tools,
  }) async {
    _validateAttachments(messages);

    // Check cache
    if (useCache && cache != null) {
      final cacheKey = ResponseCache.keyFromMessages(messages, 'auto');
      final cached = cache!.get(cacheKey);
      if (cached != null) return cached;
    }

    // Enforce budget
    if (budget != null) {
      final estimated = _estimateRequestTokens(messages);
      budget!.enforce(estimated);
    }

    // Execute with retry
    final response = await retryHandler.execute(
      () => router.route(
        messages,
        maxTokens: maxTokens,
        temperature: temperature,
        tools: tools,
      ),
    );

    // Record usage
    tokenTracker.record(response.usage);
    budget?.recordUsage(response.usage);

    // Cache response
    if (useCache && cache != null) {
      final cacheKey = ResponseCache.keyFromMessages(messages, response.model);
      cache!.put(cacheKey, response);
    }

    return response;
  }

  /// Sends a streaming completion request.
  Stream<AIStreamChunk> completeStream(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) {
    final messages = <AIMessage>[
      if (systemPrompt != null) AIMessage.system(systemPrompt),
      AIMessage.user(prompt),
    ];

    _validateAttachments(messages);

    // Enforce budget
    if (budget != null) {
      final estimated = _estimateRequestTokens(messages);
      budget!.enforce(estimated);
    }

    return router.routeStream(
      messages,
      maxTokens: maxTokens,
      temperature: temperature,
      tools: tools,
    );
  }

  /// Creates a new conversation.
  ConversationManager createConversationManager({
    AIProvider? provider,
    int maxContextTokens = 4096,
  }) {
    final p = provider ?? primaryProvider;
    final manager = ConversationManager(
      provider: p,
      maxContextTokens: maxContextTokens,
      tokenTracker: tokenTracker,
    );
    _conversationManagers[p.name] = manager;
    return manager;
  }

  /// Releases all resources.
  Future<void> dispose() async {
    for (final provider in providers) {
      await provider.dispose();
    }
    _conversationManagers.clear();
  }

  int _estimateRequestTokens(List<AIMessage> messages) {
    int total = 0;
    for (final msg in messages) {
      total += primaryProvider.estimateTokens(msg.content);
    }
    // Assume ~same tokens for output
    return total * 2;
  }

  void _validateAttachments(List<AIMessage> messages) {
    int totalBytes = 0;
    for (final m in messages) {
      if (m.attachments != null) {
        for (final att in m.attachments!) {
          if (att.bytes != null) totalBytes += att.bytes!.length;
        }
      }
    }

    final limit = primaryProvider.config.maxAttachmentBytes;
    if (limit != null && totalBytes > limit) {
      throw ArgumentError(
        'Total attachment size ($totalBytes bytes) exceeds configured limit ($limit bytes).',
      );
    }
  }
}
