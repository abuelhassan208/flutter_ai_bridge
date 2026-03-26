import '../conversation/tool_execution_loop.dart';
import '../models/ai_message.dart';
import '../models/ai_tool.dart';
import '../providers/ai_provider.dart';
import 'ai_agent.dart';

/// A standard LLM-based agent that processes input using an [AIProvider].
/// It automatically handles tool execution and stores internal memory
/// inside the shared [AgentContext].
class ConversationalAgent implements AIAgent {
  @override
  final String name;

  @override
  final String systemPrompt;

  @override
  final List<AITool> tools;

  /// The underlying provider used by this agent.
  final AIProvider provider;

  /// Optional custom parser to extract structured data from the final response
  /// and inject it into the [AgentContext].
  final void Function(String responseContent, AgentContext context)?
      outputParser;

  ConversationalAgent({
    required this.name,
    required this.systemPrompt,
    required this.provider,
    this.tools = const [],
    this.outputParser,
  });

  @override
  Future<void> execute(AgentContext context,
      {required String taskInput}) async {
    final stopwatch = Stopwatch()..start();
    context.logger.logAgentStart(name, context.conversation.id,
        contextData: {'task': taskInput});

    try {
      // 1. Prepare system instruction
      context.conversation.addMessage(AIMessage.system(systemPrompt));

      // 2. Add the current task
      context.conversation.addMessage(AIMessage.user(taskInput));

      // 3. Execution Loop
      final loop = ToolExecutionLoop(provider: provider);

      // We pass the active messages to the loop.
      // The loop will automatically append tool calls and final assistant responses
      // to the context.conversation.
      final finalResponse = await loop.execute(
        conversation: context.conversation,
        contextMessages: context.conversation.activeMessages,
        tools: tools,
      );

      // Log Token Usage
      context.logger.logTokenUsage(
        provider.name,
        provider.model,
        promptTokens: finalResponse.usage.promptTokens,
        completionTokens: finalResponse.usage.completionTokens,
        latency: finalResponse.latency,
      );

      // 4. Output parsing (if provided)
      if (outputParser != null) {
        outputParser!(finalResponse.content, context);
      }

      stopwatch.stop();
      context.logger.logAgentEnd(name, context.conversation.id,
          success: true, duration: stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      context.logger.logError('Agent $name failed on task.', e, st);
      context.logger.logAgentEnd(name, context.conversation.id,
          success: false, duration: stopwatch.elapsed);
      rethrow;
    }
  }
}
