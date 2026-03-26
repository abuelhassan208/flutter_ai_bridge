import 'ai_agent.dart';

/// Represents a distinct task to be executed by a specific agent.
class AgentTask {
  /// The description of what needs to be done.
  final String description;

  /// The specific agent assigned to execute this task.
  final AIAgent assignee;

  AgentTask({required this.description, required this.assignee});
}

/// Orchestrates a sequence of [AgentTask]s, passing the shared [AgentContext]
/// sequentially through the pipeline.
class AIPipeline {
  final List<AgentTask> sequence;

  AIPipeline({required this.sequence});

  /// Executes the pipeline sequentially.
  ///
  /// Returns the enriched [AgentContext] containing the collective memory
  /// and any written state variables.
  Future<AgentContext> execute({AgentContext? context}) async {
    final sharedContext = context ?? AgentContext();
    
    sharedContext.logger.logTrace('🚀 Starting AIPipeline with ${sequence.length} tasks.');
    final apiStopwatch = Stopwatch()..start();

    for (var i = 0; i < sequence.length; i++) {
      final task = sequence[i];
      sharedContext.logger.logTrace('➡️ Step ${i+1}: Assigning task to [${task.assignee.name}]');
      await task.assignee.execute(sharedContext, taskInput: task.description);
    }
    
    apiStopwatch.stop();
    sharedContext.logger.logTrace('✅ AIPipeline complete in ${apiStopwatch.elapsedMilliseconds}ms.');

    return sharedContext;
  }
}

/// Orchestrates a set of [AgentTask]s to run concurrently (fan-out).
///
/// Useful when multiple independent agents need to process the same
/// initial context simultaneously (e.g., one agent writes copy, another
/// generates images, another does fact-checking).
class ParallelPipeline {
  final List<AgentTask> tasks;

  ParallelPipeline({required this.tasks});

  /// Executes all tasks concurrently.
  ///
  /// Note: Because all agents share the same [AgentContext], they may
  /// write to the `variables` map concurrently. Ensure keys do not collide.
  Future<AgentContext> execute({AgentContext? context}) async {
    final sharedContext = context ?? AgentContext();
    
    sharedContext.logger.logTrace('🚀 Starting ParallelPipeline with ${tasks.length} concurrent tasks.');
    final apiStopwatch = Stopwatch()..start();

    final futures = tasks.map((task) async {
      sharedContext.logger.logTrace('➡️ Forking task to [${task.assignee.name}]');
      await task.assignee.execute(sharedContext, taskInput: task.description);
    });
    
    await Future.wait(futures);
    
    apiStopwatch.stop();
    sharedContext.logger.logTrace('✅ ParallelPipeline fan-out complete in ${apiStopwatch.elapsedMilliseconds}ms.');

    return sharedContext;
  }
}
