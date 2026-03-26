import 'dart:async';

import '../errors/ai_error.dart';
import '../errors/circuit_breaker.dart';
import '../providers/ai_provider.dart';

/// Executes a request through a chain of providers with automatic fallback.
///
/// If the first provider fails with a retryable error, the next provider
/// in the chain is tried automatically.
class FallbackChain {
  /// Ordered list of providers to try.
  final List<AIProvider> providers;

  /// Circuit breakers for health tracking.
  final Map<String, CircuitBreaker> circuitBreakers;

  FallbackChain({
    required this.providers,
    required this.circuitBreakers,
  });

  /// Executes [action] with automatic fallback to the next provider on failure.
  ///
  /// Returns the result from the first successful provider.
  /// Throws the last error if all providers fail.
  Future<T> execute<T>(
    Future<T> Function(AIProvider provider) action,
  ) async {
    AIError? lastError;

    for (final provider in providers) {
      final breaker = circuitBreakers[provider.name];

      try {
        if (breaker != null) {
          return await breaker.execute(() => action(provider));
        }
        return await action(provider);
      } on AIError catch (e) {
        lastError = e;
        // If the error is not retryable (e.g., content filter, auth),
        // don't try the next provider
        if (!e.isRetryable) {
          rethrow;
        }
        // Otherwise, continue to the next provider
        continue;
      }
    }

    throw lastError ??
        AIUnknownError(
          provider: 'FallbackChain',
          message: 'No providers available',
        );
  }
}
