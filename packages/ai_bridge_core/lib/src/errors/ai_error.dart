/// Base class for all AI Bridge errors.
///
/// Uses Dart's sealed class feature to create an exhaustive error taxonomy.
/// All provider-specific errors are mapped to these unified error types.
sealed class AIError implements Exception {
  /// Human-readable error message.
  final String message;

  /// Which provider threw this error.
  final String provider;

  /// Original error/exception from the provider (if available).
  final Object? originalError;

  /// Whether this error is retryable.
  bool get isRetryable;

  AIError({
    required this.message,
    required this.provider,
    this.originalError,
  });

  @override
  String toString() => 'AIError($provider): $message';
}

/// Rate limit exceeded — too many requests.
class AIRateLimitError extends AIError {
  @override
  bool get isRetryable => true;

  /// How long to wait before retrying (if provided by the API).
  final Duration? retryAfter;

  AIRateLimitError({
    required super.provider,
    super.message = 'Rate limit exceeded',
    this.retryAfter,
    super.originalError,
  });
}

/// Token limit exceeded — input or output too long.
class AITokenOverflowError extends AIError {
  @override
  bool get isRetryable => false;

  /// Maximum tokens allowed.
  final int? maxTokens;

  /// Tokens that were requested/used.
  final int? requestedTokens;

  AITokenOverflowError({
    required super.provider,
    super.message = 'Token limit exceeded',
    this.maxTokens,
    this.requestedTokens,
    super.originalError,
  });
}

/// Content was filtered by safety settings.
class AIContentFilterError extends AIError {
  @override
  bool get isRetryable => false;

  /// The safety category that was triggered.
  final String? category;

  AIContentFilterError({
    required super.provider,
    super.message = 'Content filtered by safety settings',
    this.category,
    super.originalError,
  });
}

/// Network error — connection issues, timeouts.
class AINetworkError extends AIError {
  @override
  bool get isRetryable => true;

  /// HTTP status code (if available).
  final int? statusCode;

  AINetworkError({
    required super.provider,
    super.message = 'Network error',
    this.statusCode,
    super.originalError,
  });
}

/// Authentication error — invalid or expired API key.
class AIAuthError extends AIError {
  @override
  bool get isRetryable => false;

  AIAuthError({
    required super.provider,
    super.message = 'Authentication failed — check your API key',
    super.originalError,
  });
}

/// Model not found or not available.
class AIModelNotFoundError extends AIError {
  @override
  bool get isRetryable => false;

  /// The model that was requested.
  final String? requestedModel;

  AIModelNotFoundError({
    required super.provider,
    super.message = 'Model not found',
    this.requestedModel,
    super.originalError,
  });
}

/// Server error from the provider (5xx).
class AIServerError extends AIError {
  @override
  bool get isRetryable => true;

  /// HTTP status code.
  final int? statusCode;

  AIServerError({
    required super.provider,
    super.message = 'Provider server error',
    this.statusCode,
    super.originalError,
  });
}

/// Budget/quota exceeded.
class AIBudgetExceededError extends AIError {
  @override
  bool get isRetryable => false;

  AIBudgetExceededError({
    super.provider = 'AIBridge',
    super.message = 'Token budget exceeded',
    super.originalError,
  });
}

/// Unknown/unclassified error.
class AIUnknownError extends AIError {
  @override
  bool get isRetryable => false;

  AIUnknownError({
    required super.provider,
    super.message = 'Unknown error',
    super.originalError,
  });
}
