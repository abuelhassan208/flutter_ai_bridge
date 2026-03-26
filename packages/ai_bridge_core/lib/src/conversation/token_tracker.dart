import '../models/ai_response.dart';

/// Tracks token usage across requests and sessions.
class TokenTracker {
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _requestCount = 0;
  double _totalCostUsd = 0;

  /// Total prompt tokens used across all requests.
  int get totalPromptTokens => _totalPromptTokens;

  /// Total completion tokens used across all requests.
  int get totalCompletionTokens => _totalCompletionTokens;

  /// Total tokens used (prompt + completion).
  int get totalTokens => _totalPromptTokens + _totalCompletionTokens;

  /// Number of requests made.
  int get requestCount => _requestCount;

  /// Total estimated cost in USD.
  double get totalCostUsd => _totalCostUsd;

  /// Records usage from a response.
  void record(AIUsage usage) {
    _totalPromptTokens += usage.promptTokens;
    _totalCompletionTokens += usage.completionTokens;
    _totalCostUsd += usage.estimatedCostUsd ?? 0;
    _requestCount++;
  }

  /// Resets all tracked data.
  void reset() {
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _requestCount = 0;
    _totalCostUsd = 0;
  }

  @override
  String toString() =>
      'TokenTracker(total: $totalTokens, requests: $requestCount, cost: \$${_totalCostUsd.toStringAsFixed(4)})';
}
