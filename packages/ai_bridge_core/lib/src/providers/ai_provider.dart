import '../models/ai_capability.dart';
import '../models/ai_config.dart';
import '../models/ai_message.dart';
import '../models/ai_response.dart';
import '../models/ai_tool.dart';

/// Core interface for AI text completion.
///
/// This is the minimal interface that all providers must implement.
abstract class AICompletionProvider {
  /// Human-readable name of this provider.
  String get name;

  /// The current model being used.
  String get model;

  /// The configuration for this provider.
  AIConfig get config;

  /// Sends a completion request and returns the full response.
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  });

  /// Releases any resources held by this provider.
  Future<void> dispose();
}

/// Interface for providers that support streaming responses.
abstract class AIStreamingProvider {
  /// Sends a completion request and returns a stream of chunks.
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  });
}

/// Full-featured AI provider interface.
///
/// Combines completion, streaming, capability discovery, and token estimation.
/// By programming against this interface, your app can switch between
/// OpenAI, Gemini, Claude, or any custom provider.
abstract class AIProvider implements AICompletionProvider, AIStreamingProvider {
  /// List of capabilities this provider supports.
  List<AICapability> get capabilities;

  /// Whether this provider supports a specific capability.
  bool supports(AICapability capability) => capabilities.contains(capability);

  /// Generates embeddings for the given text.
  ///
  /// Returns a list of doubles representing the vector embedding.
  /// Throws [UnsupportedError] if the provider doesn't support embeddings.
  Future<List<double>> embed(String text) {
    throw UnsupportedError('$name does not support embeddings');
  }

  /// Approximate characters per token for rough estimation.
  static const int kApproxCharsPerToken = 4;

  /// Estimates the number of tokens in the given text.
  ///
  /// This is an approximation — different providers tokenize differently.
  /// Default implementation uses a rough ~[kApproxCharsPerToken] chars per token estimate.
  int estimateTokens(String text) {
    return (text.length / kApproxCharsPerToken).ceil();
  }

  /// Releases any resources held by this provider.
  Future<void> dispose();
}
