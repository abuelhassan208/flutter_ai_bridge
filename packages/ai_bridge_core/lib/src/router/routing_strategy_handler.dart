import '../providers/ai_provider.dart';

/// Abstract interface for routing strategy implementations.
///
/// Each strategy decides how to order providers for a given request.
/// This replaces the previous switch-on-enum approach (OCP compliance).
abstract class RoutingStrategyHandler {
  /// Orders the available providers based on this strategy's logic.
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  );
}

/// Uses the first available provider (insertion order).
class PrimaryStrategy implements RoutingStrategyHandler {
  @override
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  ) =>
      available;
}

/// Round-robin rotation across providers.
class RoundRobinStrategy implements RoutingStrategyHandler {
  int _index = 0;

  @override
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  ) {
    if (available.isEmpty) return [];
    _index = _index % available.length;
    final reordered = [
      ...available.sublist(_index),
      ...available.sublist(0, _index),
    ];
    _index = (_index + 1) % available.length;
    return reordered;
  }
}

/// Selects providers with the lowest average latency first.
class LatencyOptimizedStrategy implements RoutingStrategyHandler {
  @override
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  ) {
    final sorted = List<AIProvider>.from(available);
    sorted.sort((a, b) {
      final aLatency = _averageLatency(latencyHistory, a.name);
      final bLatency = _averageLatency(latencyHistory, b.name);
      return aLatency.compareTo(bLatency);
    });
    return sorted;
  }

  double _averageLatency(Map<String, List<Duration>> history, String name) {
    final h = history[name];
    if (h == null || h.isEmpty) return double.infinity;
    return h.fold<int>(0, (sum, d) => sum + d.inMilliseconds) / h.length;
  }
}

/// Selects providers by estimated cost-per-token (cheapest first).
///
/// Uses `AIConfig.extraParams['cost_per_1m_input_tokens']` if available.
/// Falls back to a built-in model→price map for known models.
class CostOptimizedStrategy implements RoutingStrategyHandler {
  /// Default cost estimates per 1M input tokens for common models.
  static const Map<String, double> _defaultCosts = {
    'gpt-4o-mini': 0.15,
    'gpt-3.5-turbo': 0.5,
    'gpt-4o': 2.5,
    'gpt-4-turbo': 10.0,
    'gemini-2.0-flash': 0.1,
    'gemini-1.5-pro': 3.5,
    'claude-3-haiku': 0.25,
    'claude-3-sonnet': 3.0,
    'claude-3-opus': 15.0,
  };

  @override
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  ) {
    final sorted = List<AIProvider>.from(available);
    sorted.sort((a, b) {
      final aCost = _getCost(a);
      final bCost = _getCost(b);
      return aCost.compareTo(bCost);
    });
    return sorted;
  }

  double _getCost(AIProvider provider) {
    // Check for user-defined cost
    final extra = provider.config.extraParams;
    if (extra != null && extra.containsKey('cost_per_1m_input_tokens')) {
      return (extra['cost_per_1m_input_tokens'] as num).toDouble();
    }
    // Fallback to built-in defaults
    return _defaultCosts[provider.config.model] ?? 999.0;
  }
}

/// Selects providers in reverse insertion order (assumed quality order).
class QualityFirstStrategy implements RoutingStrategyHandler {
  @override
  List<AIProvider> selectProviders(
    List<AIProvider> available,
    Map<String, List<Duration>> latencyHistory,
  ) =>
      available.reversed.toList();
}
