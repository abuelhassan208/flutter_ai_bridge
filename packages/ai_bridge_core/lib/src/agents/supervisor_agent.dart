import '../models/ai_message.dart';
import '../models/ai_tool.dart';
import '../providers/ai_provider.dart';
import '../parsers/json_output_parser.dart';
import '../parsers/retry_output_parser.dart';
import 'ai_agent.dart';

/// A SupervisorAgent uses an LLM to determine the user's intent, then
/// dynamically routes the request to a specific sub-[AIAgent].
class SupervisorAgent implements AIAgent {
  @override
  final String name;

  @override
  final String systemPrompt;

  @override
  final List<AITool> tools = const [];

  final AICompletionProvider provider;

  /// The list of agents this supervisor can delegate work to.
  final List<AIAgent> subAgents;

  SupervisorAgent({
    required this.name,
    required this.provider,
    required this.subAgents,
    String? customPrompt,
  }) : systemPrompt = customPrompt ?? _buildDefaultPrompt(subAgents);

  /// Automatically generates a system prompt guiding the LLM to output JSON.
  static String _buildDefaultPrompt(List<AIAgent> agents) {
    final buffer = StringBuffer();
    buffer.writeln(
        'You are a Supervisor Agent. Your job is to analyze the user intent and select the appropriate specialist agent to handle the task.');
    buffer.writeln('Available Agents:');
    for (final agent in agents) {
      buffer.writeln('- ${agent.name}: ${agent.systemPrompt}');
    }
    buffer.writeln('You must respond ONLY with a valid JSON object matching this schema: {"selected_agent": "agent_name", "adjusted_task": "task_description"}');
    return buffer.toString();
  }

  @override
  Future<void> execute(AgentContext context,
      {required String taskInput}) async {
    final stopwatch = Stopwatch()..start();
    context.logger.logAgentStart(name, context.conversation.id, contextData: {'task': taskInput});

    final parser = JsonOutputParser();
    final retryParser = RetryOutputParser<Map<String, dynamic>>(
      parser: parser,
      provider: provider,
      maxRetries: 3,
      logger: context.logger,
    );

    // We isolate the supervisor's decision in a temporary list so it doesn't pollute the main conversation with JSON routing logs
    final decisionMessages = [
      AIMessage.system('$systemPrompt\n\n${parser.formatInstructions}'),
      AIMessage.user(
          'Analyze this request and choose the best agent:\n\n$taskInput'),
    ];

    try {
      final response = await provider.complete(decisionMessages);
      
      context.logger.logTokenUsage(
        provider.name,
        provider.model,
        promptTokens: response.usage.promptTokens,
        completionTokens: response.usage.completionTokens,
        latency: response.latency,
      );
      
      final jsonResponse = await retryParser.parseWithRetry(response.content, decisionMessages);

      final selectedName = jsonResponse['selected_agent'] as String?;
      final adjustedTask =
          jsonResponse['adjusted_task'] as String? ?? taskInput;

      if (selectedName != null) {
        final agent = _findAgentByName(selectedName);
        if (agent != null) {
          context.logger.logTrace('🔀 Supervisor [$name] routing to [$selectedName] with task: $adjustedTask');
          // Pass the chosen sub-agent the task
          context.write('supervisor_decision', selectedName);
          await agent.execute(context, taskInput: adjustedTask);
          
          stopwatch.stop();
          context.logger.logAgentEnd(name, context.conversation.id, duration: stopwatch.elapsed);
          return;
        }
      }

      // Fallback if parsing fails or agent not found
      context.logger.logError('Supervisor failed to find agent: $selectedName', StateError('Agent not found'));
      context.conversation.addMessage(AIMessage.assistant(
          'Supervisor failed to route task "$taskInput". Output: ${response.content}'));
          
      stopwatch.stop();
      context.logger.logAgentEnd(name, context.conversation.id, success: false, duration: stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      context.logger.logError('Supervisor $name encountered an error', e, st);
      context.conversation
          .addMessage(AIMessage.assistant('Supervisor Error: $e'));
      context.logger.logAgentEnd(name, context.conversation.id, success: false, duration: stopwatch.elapsed);
    }
  }

  AIAgent? _findAgentByName(String name) {
    for (final agent in subAgents) {
      if (agent.name.toLowerCase() == name.toLowerCase()) {
        return agent;
      }
    }
    return null;
  }
}
