import 'dart:async';
import 'dart:math';

import 'ai_error.dart';

/// Handles automatic retries for retryable AI errors.
///
/// Uses exponential backoff with jitter to avoid thundering herd.
class RetryHandler {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay between retries.
  final Duration baseDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Random for jitter calculation.
  final Random _random = Random();

  RetryHandler({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Executes [action] with automatic retries on retryable errors.
  ///
  /// Returns the result of [action] on success.
  /// Throws the last error if all retries are exhausted.
  Future<T> execute<T>(Future<T> Function() action) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } on AIError catch (e) {
        attempt++;
        if (!e.isRetryable || attempt >= maxRetries) {
          rethrow;
        }

        final delay = _calculateDelay(attempt, e);
        await Future.delayed(delay);
      }
    }
  }

  /// Calculates the delay for the given attempt with exponential backoff + jitter.
  Duration _calculateDelay(int attempt, AIError error) {
    // If the error provides a retry-after hint, use it
    if (error is AIRateLimitError && error.retryAfter != null) {
      return error.retryAfter!;
    }

    // Exponential backoff: baseDelay * 2^attempt
    final exponentialMs = baseDelay.inMilliseconds * pow(2, attempt - 1);

    // Add jitter (±25%)
    final jitter =
        (exponentialMs * 0.25 * (2 * _random.nextDouble() - 1)).round();
    final delayMs = (exponentialMs + jitter).round();

    // Cap at maxDelay
    return Duration(milliseconds: min(delayMs, maxDelay.inMilliseconds));
  }
}
