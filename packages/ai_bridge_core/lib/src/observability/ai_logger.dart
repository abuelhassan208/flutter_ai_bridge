/// An interface for logging and tracing AI events, execution steps, and token usage.
///
/// Implementing this interface allows developers to pipe telemetry data to
/// services like Datadog, Firebase, LangSmith, or simply the console.
abstract class AILogger {
  /// General trace logging.
  void logTrace(String message, {Map<String, dynamic>? data});

  /// Called when an Agent begins execution.
  void logAgentStart(String agentName, String taskId,
      {Map<String, dynamic>? contextData});

  /// Called when an Agent completes execution.
  void logAgentEnd(String agentName, String taskId,
      {bool success = true, Duration? duration});

  /// Called when an LLM requests a tool execution.
  void logToolCall(String toolName, Map<String, dynamic> args);

  /// Called when a tool returns a result.
  void logToolResult(String toolName, String result);

  /// Called when an API provider returns token consumption metrics.
  void logTokenUsage(
    String provider,
    String model, {
    required int promptTokens,
    required int completionTokens,
    required Duration latency,
  });

  /// Called for errors.
  void logError(String message, Object error, [StackTrace? stackTrace]);
}
