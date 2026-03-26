/// Configuration for an AI provider.
class AIConfig {
  /// Default maximum attachment size: 20 MB.
  static const int kDefaultMaxAttachmentBytes = 20 * 1024 * 1024;

  /// API key for the provider.
  final String apiKey;

  /// The model to use (e.g., 'gpt-4o', 'gemini-2.0-flash').
  final String model;

  /// Maximum tokens to generate in the response.
  final int? maxTokens;

  /// Temperature for response randomness (0.0 = deterministic, 2.0 = creative).
  final double? temperature;

  /// Top-p (nucleus sampling) parameter.
  final double? topP;

  /// Optional base URL override for the API.
  final String? baseUrl;

  /// Request timeout duration.
  final Duration timeout;

  /// System prompt to use by default.
  final String? systemPrompt;

  /// Additional provider-specific parameters.
  final Map<String, dynamic>? extraParams;

  /// Maximum total bytes for attachments in a single request to prevent OOM or 413 Payload Too Large.
  final int? maxAttachmentBytes;

  const AIConfig({
    required this.apiKey,
    required this.model,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.systemPrompt,
    this.extraParams,
    this.maxAttachmentBytes = kDefaultMaxAttachmentBytes,
  });

  /// Creates a copy with modified fields.
  AIConfig copyWith({
    String? apiKey,
    String? model,
    int? maxTokens,
    double? temperature,
    double? topP,
    String? baseUrl,
    Duration? timeout,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
    int? maxAttachmentBytes,
  }) {
    return AIConfig(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      baseUrl: baseUrl ?? this.baseUrl,
      timeout: timeout ?? this.timeout,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      extraParams: extraParams ?? this.extraParams,
      maxAttachmentBytes: maxAttachmentBytes ?? this.maxAttachmentBytes,
    );
  }
}

/// A request to an AI provider.
class AIRequest {
  /// The messages to send (conversation history).
  final List<dynamic> messages;

  /// Override configuration for this specific request.
  final AIConfig? configOverride;

  /// Maximum tokens for this request.
  final int? maxTokens;

  /// Temperature for this request.
  final double? temperature;

  /// Whether to stream the response.
  final bool stream;

  const AIRequest({
    required this.messages,
    this.configOverride,
    this.maxTokens,
    this.temperature,
    this.stream = false,
  });
}
