import '../models/ai_message.dart';
import '../models/ai_response.dart';
import '../models/ai_tool.dart';
import '../models/conversation.dart';
import '../providers/ai_provider.dart';
import 'token_tracker.dart';
import 'storage_provider.dart';
import 'tool_execution_loop.dart';

/// Manages conversations with AI providers.
///
/// Handles context tracking, token counting, conversation history,
/// and automatic summarization for long conversations.
class ConversationManager {
  /// The AI provider to use for completions.
  final AIProvider provider;

  /// Maximum tokens to keep in context window.
  final int maxContextTokens;

  /// Maximum recursive tool call iterations before aborting.
  final int maxToolIterations;

  /// Active conversations keyed by ID.
  final Map<String, Conversation> _conversations = {};

  /// Token tracker for monitoring usage.
  final TokenTracker tokenTracker;

  /// Optional storage provider for saving and loading conversations automatically.
  final StorageProvider? storage;

  ConversationManager({
    required this.provider,
    this.maxContextTokens = 4096,
    this.maxToolIterations = 10,
    TokenTracker? tokenTracker,
    this.storage,
  }) : tokenTracker = tokenTracker ?? TokenTracker();

  /// Creates a new conversation with an optional system prompt.
  Conversation create({String? systemPrompt, String? title}) {
    final conversation = Conversation(title: title);

    if (systemPrompt != null) {
      conversation.addMessage(AIMessage.system(systemPrompt));
    }

    _conversations[conversation.id] = conversation;
    storage?.saveConversation(conversation);
    return conversation;
  }

  /// Gets a conversation by ID from memory.
  Conversation? get(String conversationId) => _conversations[conversationId];

  /// Asynchronously loads a conversation from storage.
  Future<Conversation?> load(String conversationId) async {
    if (storage == null) return null;
    final conv = await storage!.loadConversation(conversationId);
    if (conv != null) {
      _conversations[conv.id] = conv;
    }
    return conv;
  }

  /// Asynchronously loads all conversations from storage into memory.
  Future<List<Conversation>> loadAll() async {
    if (storage == null) return [];
    final convs = await storage!.loadAllConversations();
    for (final conv in convs) {
      _conversations[conv.id] = conv;
    }
    return convs;
  }

  /// Returns all active conversations.
  List<Conversation> get all => _conversations.values.toList();

  /// Sends a message in a conversation and returns the response.
  Future<AIResponse> send(
    String conversationId,
    String message, {
    List<AITool>? tools,
  }) async {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      throw StateError('Conversation $conversationId not found');
    }

    // Add user message
    conversation.addMessage(AIMessage.user(message));
    storage?.saveConversation(conversation);

    return _processConversation(conversation, tools);
  }

  Future<AIResponse> _processConversation(
    Conversation conversation,
    List<AITool>? tools,
  ) async {
    // Trim context if needed
    final messages = _trimToFit(conversation);

    final toolLoop = ToolExecutionLoop(
      provider: provider,
      maxIterations: maxToolIterations,
    );

    final response = await toolLoop.execute(
      conversation: conversation,
      contextMessages: messages,
      tools: tools,
    );

    // Track tokens
    conversation.totalTokensUsed += response.usage.totalTokens;
    tokenTracker.record(response.usage);
    storage?.saveConversation(conversation);
    return response;
  }

  /// Sends a message in a conversation and returns a stream of chunks.
  Stream<AIStreamChunk> sendStream(
    String conversationId,
    String message,
  ) async* {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      throw StateError('Conversation $conversationId not found');
    }

    // Add user message
    conversation.addMessage(AIMessage.user(message));
    storage?.saveConversation(conversation);

    // Trim context if needed
    final messages = _trimToFit(conversation);

    // Stream from provider
    final buffer = StringBuffer();
    await for (final chunk in provider.completeStream(messages)) {
      buffer.write(chunk.text);
      yield chunk;

      // Track tokens from final chunk
      if (chunk.isComplete && chunk.usage != null) {
        conversation.totalTokensUsed += chunk.usage!.totalTokens;
        tokenTracker.record(chunk.usage!);
      }
    }

    // Add assistant response
    conversation.addMessage(AIMessage.assistant(buffer.toString()));
    storage?.saveConversation(conversation);
  }

  /// Deletes a conversation from memory and storage.
  void delete(String conversationId) {
    _conversations.remove(conversationId);
    storage?.deleteConversation(conversationId);
  }

  /// Clears all conversations from memory (but not storage).
  void clearAll() {
    _conversations.clear();
  }

  /// Trims the conversation to fit within the context window.
  ///
  /// Keeps the system message + most recent messages that fit.
  List<AIMessage> _trimToFit(Conversation conversation) {
    final messages = conversation.activeMessages;

    // Estimate total tokens
    int totalTokens = 0;
    for (final msg in messages) {
      totalTokens += provider.estimateTokens(msg.content);
    }

    // If within limits, send all
    if (totalTokens <= maxContextTokens) {
      return List.from(messages);
    }

    // Keep system message + trim oldest messages
    final result = <AIMessage>[];
    final systemMsg = conversation.systemMessage;
    if (systemMsg != null) {
      result.add(systemMsg);
      totalTokens = provider.estimateTokens(systemMsg.content);
    } else {
      totalTokens = 0;
    }

    // Add messages from most recent, backward
    final nonSystemMessages =
        messages.where((m) => m.role != AIRole.system).toList();
    for (int i = nonSystemMessages.length - 1; i >= 0; i--) {
      final msgTokens = provider.estimateTokens(nonSystemMessages[i].content);
      if (totalTokens + msgTokens > maxContextTokens) break;
      result.insert(systemMsg != null ? 1 : 0, nonSystemMessages[i]);
      totalTokens += msgTokens;
    }

    return result;
  }
}
