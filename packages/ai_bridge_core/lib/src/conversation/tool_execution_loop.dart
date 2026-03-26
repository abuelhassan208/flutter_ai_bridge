import '../models/ai_message.dart';
import '../models/ai_response.dart';
import '../models/ai_tool.dart';
import '../models/conversation.dart';
import '../providers/ai_provider.dart';
import '../observability/ai_logger.dart';

/// Handles the autonomous tool execution loop.
class ToolExecutionLoop {
  final AIProvider provider;
  final int maxIterations;
  final AILogger? logger;

  ToolExecutionLoop({
    required this.provider,
    this.maxIterations = 10,
    this.logger,
  });

  Future<AIResponse> execute({
    required Conversation conversation,
    required List<AIMessage> contextMessages,
    List<AITool>? tools,
    int depth = 0,
  }) async {
    if (depth >= maxIterations) {
      throw StateError('Tool execution loop exceeded maximum depth.');
    }

    final response = await provider.complete(contextMessages, tools: tools);

    if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
      conversation.addMessage(AIMessage.assistant(
        response.content,
        toolCalls: response.toolCalls,
      ));

      for (final tc in response.toolCalls!) {
        final tool = _findToolByName(tools, tc.name);
        
        logger?.logToolCall(tc.name, tc.arguments);

        String result;
        if (tool != null && tool.execute != null) {
          try {
            result = await tool.execute!(tc.arguments);
          } catch (e, st) {
            result = 'Error executing tool: $e';
            logger?.logError('Tool ${tc.name} execution failed', e, st);
          }
        } else {
          result = 'Error: Tool ${tc.name} not found or has no execute function.';
        }

        logger?.logToolResult(tc.name, result);
        conversation.addMessage(AIMessage.toolResult(tc.id, result));
      }

      final updatedContext = conversation.activeMessages;
      return execute(
        conversation: conversation,
        contextMessages: updatedContext,
        tools: tools,
        depth: depth + 1,
      );
    }

    // No tool calls — final response
    conversation.addMessage(AIMessage.assistant(response.content));
    return response;
  }

  AITool? _findToolByName(List<AITool>? tools, String name) {
    if (tools == null) return null;
    for (final tool in tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
