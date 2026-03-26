import 'dart:collection';
import '../models/ai_message.dart';

/// Represents a short-term memory buffer for an Agent.
///
/// Helps maintain context within a certain token or message limit, dropping
/// older messages (a sliding window) to prevent context exhaustion in long-running
/// multi-agent interactions.
class AgentMemory {
  final int maxMessages;
  final DoubleLinkedQueue<AIMessage> _buffer = DoubleLinkedQueue<AIMessage>();

  AgentMemory({this.maxMessages = 100});

  /// Adds a new message to the agent's memory.
  /// If the capacity is exceeded, the oldest message is removed.
  void addMessage(AIMessage message) {
    if (_buffer.length >= maxMessages) {
      _buffer.removeFirst();
    }
    _buffer.addLast(message);
  }

  /// Adds multiple messages to the agent's memory.
  void addMessages(Iterable<AIMessage> messages) {
    for (final msg in messages) {
      addMessage(msg);
    }
  }

  /// Returns all messages currently held in memory.
  List<AIMessage> get activeMemory => _buffer.toList();

  /// Clears the memory buffer entirely.
  void clear() {
    _buffer.clear();
  }
}
