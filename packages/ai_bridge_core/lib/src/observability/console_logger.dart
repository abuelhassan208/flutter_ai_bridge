import 'dart:developer' as developer;
import 'ai_logger.dart';

/// A simple implementation of [AILogger] that outputs traces to the Dart console.
class ConsoleAILogger implements AILogger {
  final bool enableDebugLogging;

  const ConsoleAILogger({this.enableDebugLogging = true});

  @override
  void logTrace(String message, {Map<String, dynamic>? data}) {
    if (!enableDebugLogging) return;
    developer.log('🔍 [TRACE] $message ${data ?? ''}', name: 'AIBridge');
  }

  @override
  void logAgentStart(String agentName, String taskId,
      {Map<String, dynamic>? contextData}) {
    developer.log('🤖 [AGENT START] $agentName ($taskId)', name: 'AIBridge');
  }

  @override
  void logAgentEnd(String agentName, String taskId,
      {bool success = true, Duration? duration}) {
    final status = success ? '✅ SUCCESS' : '❌ FAILED';
    final durStr = duration != null ? ' in ${duration.inMilliseconds}ms' : '';
    developer.log('🤖 [AGENT END] $agentName ($taskId) - $status$durStr',
        name: 'AIBridge');
  }

  @override
  void logToolCall(String toolName, Map<String, dynamic> args) {
    developer.log('🛠️ [TOOL CALL] $toolName($args)', name: 'AIBridge');
  }

  @override
  void logToolResult(String toolName, String result) {
    final snippet =
        result.length > 50 ? '${result.substring(0, 50)}...' : result;
    developer.log('📥 [TOOL RESULT] $toolName -> $snippet', name: 'AIBridge');
  }

  @override
  void logTokenUsage(
    String provider,
    String model, {
    required int promptTokens,
    required int completionTokens,
    required Duration latency,
  }) {
    final total = promptTokens + completionTokens;
    developer.log(
      '🪙 [TOKENS] $provider/$model | $promptTokens + $completionTokens = $total | Latency: ${latency.inMilliseconds}ms',
      name: 'AIBridge',
    );
  }

  @override
  void logError(String message, Object error, [StackTrace? stackTrace]) {
    developer.log(
      '🚨 [ERROR] $message',
      name: 'AIBridge',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
