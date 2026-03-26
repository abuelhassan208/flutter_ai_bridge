import 'package:uuid/uuid.dart';
import 'ai_tool.dart';

/// Represents a role in an AI conversation.
enum AIRole {
  /// System instructions that set the AI's behavior.
  system,

  /// Messages from the user.
  user,

  /// Messages from the assistant that may include tool calls.
  assistant,

  /// Outputs from a tool execution, sent back to the AI.
  tool,
}

/// The type of content in an attachment.
enum AIAttachmentType {
  image,
  audio,
  video,
  document,
  file,
}

/// An attachment that can be sent with a message.
class AIAttachment {
  /// The type of this attachment.
  final AIAttachmentType type;

  /// Raw bytes of the attachment (for in-memory data).
  final List<int>? bytes;

  /// URL of the attachment (for remote resources).
  final String? url;

  /// File path (for local files).
  final String? filePath;

  /// MIME type of the attachment.
  final String? mimeType;

  /// Display name for the attachment.
  final String? name;

  AIAttachment({
    required this.type,
    this.bytes,
    this.url,
    this.filePath,
    this.mimeType,
    this.name,
  }) : assert(
          bytes != null || url != null || filePath != null,
          'At least one of bytes, url, or filePath must be provided.',
        );

  /// Creates an image attachment from bytes.
  factory AIAttachment.imageBytes(List<int> bytes, {String? mimeType}) {
    return AIAttachment(
      type: AIAttachmentType.image,
      bytes: bytes,
      mimeType: mimeType ?? 'image/png',
    );
  }

  /// Creates an image attachment from a URL.
  factory AIAttachment.imageUrl(String url) {
    return AIAttachment(
      type: AIAttachmentType.image,
      url: url,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (bytes != null) 'bytes': bytes,
      if (url != null) 'url': url,
      if (filePath != null) 'filePath': filePath,
      if (mimeType != null) 'mimeType': mimeType,
      if (name != null) 'name': name,
    };
  }

  factory AIAttachment.fromJson(Map<String, dynamic> json) {
    return AIAttachment(
      type: AIAttachmentType.values.firstWhere((e) => e.name == json['type']),
      bytes:
          json['bytes'] != null ? List<int>.from(json['bytes'] as List) : null,
      url: json['url'] as String?,
      filePath: json['filePath'] as String?,
      mimeType: json['mimeType'] as String?,
      name: json['name'] as String?,
    );
  }
}

/// A single message in an AI conversation.
class AIMessage {
  /// The role of the sender.
  final AIRole role;

  /// The text content of the message.
  final String content;

  /// Optional attachments (images, audio, files).
  final List<AIAttachment>? attachments;

  /// Optional metadata for provider-specific data.
  final Map<String, dynamic>? metadata;

  /// When the message was created.
  final DateTime timestamp;

  /// Unique identifier for this message.
  final String id;

  /// For 'assistant' role: a list of tool invocations requested by the model.
  final List<AIToolCall>? toolCalls;

  /// For 'tool' role: the specific ID of the tool call this message answers.
  final String? toolCallId;

  AIMessage({
    required this.role,
    required this.content,
    this.attachments,
    this.metadata,
    this.toolCalls,
    this.toolCallId,
    DateTime? timestamp,
    String? id,
  })  : timestamp = timestamp ?? DateTime.now(),
        id = id ?? _generateId();

  /// Creates a system message.
  factory AIMessage.system(String content) {
    return AIMessage(role: AIRole.system, content: content);
  }

  /// Creates a user message.
  factory AIMessage.user(String content, {List<AIAttachment>? attachments}) {
    return AIMessage(
      role: AIRole.user,
      content: content,
      attachments: attachments,
    );
  }

  /// Creates an assistant message (optionally with tool calls).
  factory AIMessage.assistant(String content, {List<AIToolCall>? toolCalls}) {
    return AIMessage(
      role: AIRole.assistant,
      content: content,
      toolCalls: toolCalls,
    );
  }

  /// Creates a tool result message.
  factory AIMessage.toolResult(String toolCallId, String content) {
    return AIMessage(
      role: AIRole.tool,
      content: content,
      toolCallId: toolCallId,
    );
  }

  /// Creates a copy with modified fields.
  AIMessage copyWith({
    AIRole? role,
    String? content,
    List<AIAttachment>? attachments,
    Map<String, dynamic>? metadata,
    List<AIToolCall>? toolCalls,
    String? toolCallId,
  }) {
    return AIMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      toolCalls: toolCalls ?? this.toolCalls,
      toolCallId: toolCallId ?? this.toolCallId,
      timestamp: timestamp,
      id: id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      if (attachments != null)
        'attachments': attachments!.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (toolCalls != null)
        'toolCalls': toolCalls!.map((e) => e.toJson()).toList(),
      if (toolCallId != null) 'toolCallId': toolCallId,
      'timestamp': timestamp.toIso8601String(),
      'id': id,
    };
  }

  factory AIMessage.fromJson(Map<String, dynamic> json) {
    return AIMessage(
      role: AIRole.values.firstWhere((e) => e.name == json['role']),
      content: json['content'] as String,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((e) => AIAttachment.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      toolCalls: json['toolCalls'] != null
          ? (json['toolCalls'] as List)
              .map((e) => AIToolCall.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      toolCallId: json['toolCallId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      id: json['id'] as String,
    );
  }

  static final _uuid = Uuid();
  static String _generateId() => _uuid.v4();

  @override
  String toString() =>
      'AIMessage($role: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
}
