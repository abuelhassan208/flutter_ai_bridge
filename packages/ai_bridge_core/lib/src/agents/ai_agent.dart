import '../models/ai_tool.dart';
import '../models/conversation.dart';
import '../observability/ai_logger.dart';
import '../observability/console_logger.dart';

/// Represents the shared context that is passed between agents or tasks.
/// It acts like a Blackboard where agents can read and write intermediate outputs.
class AgentContext {
  final Map<String, dynamic> variables;
  final Conversation conversation;
  final AILogger logger;

  AgentContext({
    Map<String, dynamic>? variables,
    Conversation? conversation,
    AILogger? logger,
  })  : variables = variables ?? <String, dynamic>{},
        logger = logger ?? const ConsoleAILogger(),
        conversation = conversation ??
            Conversation(id: 'ctx_${DateTime.now().millisecondsSinceEpoch}');

  /// Read a variable from the context
  T? read<T>(String key) {
    final value = variables[key];
    if (value is T) return value;
    return null;
  }

  /// Write a variable to the context
  void write(String key, dynamic value) {
    variables[key] = value;
  }
}

/// Base class representing an Autonomous AI Agent.
/// An agent has a persona/role, a set of available tools, and the logic to
/// execute tasks given an input context.
abstract class AIAgent {
  /// The specific name and role of this agent (e.g., "Research Analyst")
  String get name;

  /// The system prompt defining the agent's behavior
  String get systemPrompt;

  /// Tools available specifically to this agent
  List<AITool> get tools => const [];

  /// Executes a task using the agent's capabilities and modifies the context
  Future<void> execute(AgentContext context, {required String taskInput});
}
