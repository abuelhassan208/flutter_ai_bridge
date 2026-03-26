import 'dart:collection';
import 'package:uuid/uuid.dart';
import 'ai_message.dart';

/// Represents a conversation with an AI provider.
class Conversation {
  /// Unique identifier for this conversation.
  final String id;

  /// Internal mutable messages list.
  final List<AIMessage> _messages;

  /// Read-only view of the messages in this conversation.
  List<AIMessage> get messages => UnmodifiableListView(_messages);

  /// Total tokens used in this conversation.
  int totalTokensUsed;

  /// When the conversation was created.
  final DateTime createdAt;

  /// When the conversation was last updated.
  DateTime updatedAt;

  /// Optional title for the conversation.
  String? title;

  /// Optional metadata.
  final Map<String, dynamic> metadata;

  Conversation({
    String? id,
    List<AIMessage>? messages,
    this.totalTokensUsed = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.title,
    Map<String, dynamic>? metadata,
  })  : id = id ?? _generateId(),
        _messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        metadata = metadata ?? {};

  /// Adds a message to the conversation.
  void addMessage(AIMessage message) {
    _messages.add(message);
    updatedAt = DateTime.now();
  }

  /// Returns messages suitable for sending to an AI provider.
  List<AIMessage> get activeMessages => UnmodifiableListView(_messages);

  /// Returns the system prompt if one exists.
  AIMessage? get systemMessage {
    final systemMessages =
        _messages.where((m) => m.role == AIRole.system).toList();
    return systemMessages.isNotEmpty ? systemMessages.last : null;
  }

  /// Number of messages in the conversation.
  int get messageCount => _messages.length;

  /// Whether the conversation is empty (no user/assistant messages).
  bool get isEmpty => _messages.where((m) => m.role != AIRole.system).isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messages': _messages.map((e) => e.toJson()).toList(),
      'totalTokensUsed': totalTokensUsed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (title != null) 'title': title,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      messages: (json['messages'] as List)
          .map((e) => AIMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalTokensUsed: json['totalTokensUsed'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      title: json['title'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static final _uuid = Uuid();
  static String _generateId() => _uuid.v4();

  @override
  String toString() =>
      'Conversation(id: $id, messages: $messageCount, tokens: $totalTokensUsed)';
}
