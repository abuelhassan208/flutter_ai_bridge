import '../models/ai_capability.dart';
import '../models/ai_message.dart';
import '../models/ai_response.dart';
import '../models/ai_tool.dart';
import '../providers/ai_provider.dart';
import '../errors/circuit_breaker.dart';
import '../errors/ai_error.dart';
import 'fallback_chain.dart';
import 'routing_strategy_handler.dart';

/// Strategy for routing requests to providers.
enum RoutingStrategy {
  /// Use the first available provider.
  primary,

  /// Choose the provider with the lowest cost.
  costOptimized,

  /// Choose the provider with the lowest latency.
  latencyOptimized,

  /// Choose the provider with the highest quality.
  qualityFirst,

  /// Round-robin between providers.
  roundRobin,
}

/// Smart router that decides which AI provider handles each request.
///
/// Supports multiple routing strategies, capability-based filtering,
/// and automatic fallback when a provider fails.
class AIRouter {
  /// Available providers to route to.
  final List<AIProvider> providers;

  /// The strategy handler for provider selection.
  final RoutingStrategyHandler strategyHandler;

  /// Circuit breakers for each provider (keyed by provider name).
  final Map<String, CircuitBreaker> _circuitBreakers = {};

  /// Latency history for latency-based routing.
  final Map<String, List<Duration>> _latencyHistory = {};

  /// Creates a router with a [RoutingStrategyHandler].
  AIRouter({
    required this.providers,
    RoutingStrategyHandler? strategyHandler,
    RoutingStrategy strategy = RoutingStrategy.primary,
  }) : strategyHandler = strategyHandler ?? strategy.toHandler() {
    for (final provider in providers) {
      _circuitBreakers[provider.name] = CircuitBreaker(name: provider.name);
    }
  }

  /// Routes a completion request to the best available provider.
  Future<AIResponse> route(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    AICapability? requiredCapability,
    List<AITool>? tools,
  }) async {
    final chain = FallbackChain(
      providers: _selectProviders(requiredCapability),
      circuitBreakers: _circuitBreakers,
    );

    final response = await chain.execute(
      (provider) => provider.complete(
        messages,
        maxTokens: maxTokens,
        temperature: temperature,
        tools: tools,
      ),
    );

    _recordLatency(response.provider, response.latency);
    return response;
  }

  /// Routes a streaming request to the best available provider.
  Stream<AIStreamChunk> routeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    AICapability? requiredCapability,
    List<AITool>? tools,
  }) async* {
    final selectedProviders = _selectProviders(requiredCapability);
    if (selectedProviders.isEmpty) {
      throw StateError('No providers available for the requested capability');
    }

    AIError? lastError;

    for (final provider in selectedProviders) {
      final breaker = _circuitBreakers[provider.name];
      if (breaker != null && !breaker.isAllowed) continue;

      bool hasYielded = false;
      try {
        final stream = provider.completeStream(
          messages,
          maxTokens: maxTokens,
          temperature: temperature,
          tools: tools,
        );

        await for (final chunk in stream) {
          hasYielded = true;
          yield chunk;
        }

        if (breaker != null) breaker.recordSuccess();
        return; // Successfully completed
      } on AIError catch (e) {
        lastError = e;
        if (breaker != null) breaker.recordFailure();

        // If we already yielded chunks, we can't cleanly fallback
        // Or if the error is fatal (auth, content filter)
        if (hasYielded || !e.isRetryable) {
          rethrow;
        }
        // If it's a network error before yielding, try the next provider
        continue;
      } catch (e) {
        if (breaker != null) breaker.recordFailure();
        rethrow;
      }
    }

    throw lastError ??
        AIUnknownError(
          provider: 'AIRouter',
          message: 'All providers failed to stream',
        );
  }

  /// Selects and orders providers based on the routing strategy.
  List<AIProvider> _selectProviders([AICapability? requiredCapability]) {
    var available = providers.where((p) {
      final breaker = _circuitBreakers[p.name];
      return breaker == null || breaker.isAllowed;
    }).toList();

    // Filter by capability if specified
    if (requiredCapability != null) {
      available =
          available.where((p) => p.supports(requiredCapability)).toList();
    }

    return strategyHandler.selectProviders(available, _latencyHistory);
  }

  void _recordLatency(String providerName, Duration latency) {
    _latencyHistory.putIfAbsent(providerName, () => []);
    final history = _latencyHistory[providerName]!;
    history.add(latency);
    // Keep last 20 entries
    if (history.length > 20) {
      history.removeAt(0);
    }
  }
}

/// Extension for backward compatibility: convert enum to handler.
extension RoutingStrategyExtension on RoutingStrategy {
  RoutingStrategyHandler toHandler() {
    switch (this) {
      case RoutingStrategy.primary:
        return PrimaryStrategy();
      case RoutingStrategy.roundRobin:
        return RoundRobinStrategy();
      case RoutingStrategy.latencyOptimized:
        return LatencyOptimizedStrategy();
      case RoutingStrategy.costOptimized:
        return CostOptimizedStrategy();
      case RoutingStrategy.qualityFirst:
        return QualityFirstStrategy();
    }
  }
}
