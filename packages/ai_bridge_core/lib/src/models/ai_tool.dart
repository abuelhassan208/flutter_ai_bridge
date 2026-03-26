import 'package:equatable/equatable.dart';

/// Defines a tool or function that the AI can call.
class AITool {
  /// The name of the function to be called.
  /// Must contain only a-z, A-Z, 0-9, or underscores.
  final String name;

  /// A description of what the function does.
  final String description;

  /// JSON schema defining the parameters the function accepts.
  final Map<String, dynamic> parameters;

  /// The Dart function to execute when the AI invokes this tool.
  final Future<String> Function(Map<String, dynamic> args)? execute;

  AITool({
    required this.name,
    required this.description,
    required this.parameters,
    this.execute,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'parameters': parameters,
    };
  }
}

/// Represents a specific invocation of a tool requested by the AI.
class AIToolCall extends Equatable {
  /// Unique identifier for this specific tool call (required by OpenAI).
  final String id;

  /// The name of the tool to be called.
  final String name;

  /// The JSON-formatted arguments provided by the AI.
  final Map<String, dynamic> arguments;

  AIToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arguments': arguments,
    };
  }

  factory AIToolCall.fromJson(Map<String, dynamic> json) {
    return AIToolCall(
      id: json['id'] as String,
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>,
    );
  }

  @override
  List<Object?> get props => [id, name, arguments];
}
