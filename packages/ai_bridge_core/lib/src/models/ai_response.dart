import 'package:equatable/equatable.dart';
import 'ai_tool.dart';

/// Token usage information from an AI response.
class AIUsage extends Equatable {
  /// Number of tokens in the input/prompt.
  final int promptTokens;

  /// Number of tokens in the generated response.
  final int completionTokens;

  /// Total tokens used (prompt + completion).
  int get totalTokens => promptTokens + completionTokens;

  /// Estimated cost in USD (if available).
  final double? estimatedCostUsd;

  const AIUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.estimatedCostUsd,
  });

  /// Zero usage (for cases where usage is not tracked).
  static const zero = AIUsage(promptTokens: 0, completionTokens: 0);

  AIUsage operator +(AIUsage other) {
    return AIUsage(
      promptTokens: promptTokens + other.promptTokens,
      completionTokens: completionTokens + other.completionTokens,
      estimatedCostUsd: (estimatedCostUsd ?? 0) + (other.estimatedCostUsd ?? 0),
    );
  }

  @override
  String toString() =>
      'AIUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';

  @override
  List<Object?> get props => [promptTokens, completionTokens, estimatedCostUsd];
}

/// A unified response from any AI provider.
class AIResponse {
  /// The generated text content.
  final String content;

  /// Token usage information.
  final AIUsage usage;

  /// The model that generated this response.
  final String model;

  /// The provider that served this response.
  final String provider;

  /// How long the request took.
  final Duration latency;

  /// The finish reason (e.g., 'stop', 'length', 'content_filter').
  final String? finishReason;

  /// Provider-specific metadata.
  final Map<String, dynamic>? metadata;

  /// Tool invocations requested by the model.
  final List<AIToolCall>? toolCalls;

  /// When the response was received.
  final DateTime timestamp;

  AIResponse({
    required this.content,
    required this.usage,
    required this.model,
    required this.provider,
    required this.latency,
    this.finishReason,
    this.metadata,
    this.toolCalls,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'AIResponse(provider: $provider, model: $model, tokens: ${usage.totalTokens}, latency: ${latency.inMilliseconds}ms)';
}

/// A single chunk from a streaming AI response.
class AIStreamChunk {
  /// The text content of this chunk.
  final String text;

  /// Whether this is the final chunk.
  final bool isComplete;

  /// Cumulative usage (only available on the final chunk).
  final AIUsage? usage;

  /// The finish reason (only on the final chunk).
  final String? finishReason;

  /// The provider that generated this chunk.
  final String? provider;

  /// The model used.
  final String? model;

  /// Tool invocations requested by the model.
  final List<AIToolCall>? toolCalls;

  const AIStreamChunk({
    required this.text,
    this.isComplete = false,
    this.usage,
    this.finishReason,
    this.provider,
    this.model,
    this.toolCalls,
  });

  @override
  String toString() =>
      'AIStreamChunk("${text.length > 30 ? '${text.substring(0, 30)}...' : text}", complete: $isComplete)';
}
