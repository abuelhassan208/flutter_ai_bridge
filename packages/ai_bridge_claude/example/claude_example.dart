/// Comprehensive usage examples for `ai_bridge_claude`.
///
/// Demonstrates:
/// - Basic completion with system prompt
/// - Streaming responses
/// - Tool use (function calling)
library;

import 'dart:io';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_claude/ai_bridge_claude.dart';

void main() async {
  // ─────────────────────────────────────────
  // Setup
  // ─────────────────────────────────────────
  final provider = ClaudeProvider(
    config: AIConfig(
      apiKey: Platform.environment['ANTHROPIC_API_KEY'] ?? 'sk-ant-...',
      model: 'claude-3-5-sonnet-20241022',
    ),
  );

  // ─────────────────────────────────────────
  // 1. Basic Completion
  // ─────────────────────────────────────────
  print('── 1. Basic Completion ──');
  final response = await provider.complete([
    AIMessage.system('You are a senior Dart developer.'),
    AIMessage.user('What are extension types in Dart 3?'),
  ]);
  print('Response: ${response.content}');
  print('Tokens: ${response.usage.totalTokens}');

  // ─────────────────────────────────────────
  // 2. Streaming
  // ─────────────────────────────────────────
  print('\n── 2. Streaming ──');
  final stream = provider.completeStream([
    AIMessage.user('Write a haiku about programming.'),
  ]);

  await for (final chunk in stream) {
    stdout.write(chunk.text);
  }
  print('');

  // ─────────────────────────────────────────
  // 3. Tool Use
  // ─────────────────────────────────────────
  print('\n── 3. Tool Use ──');
  final fileTool = AITool(
    name: 'read_file',
    description: 'Read the contents of a file from disk',
    parameters: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Absolute file path to read',
        },
      },
      'required': ['path'],
    },
    execute: (args) async => '{"content": "void main() { print(\'Hello\'); }"}',
  );

  final toolResponse = await provider.complete(
    [AIMessage.user('Read the file at /tmp/main.dart and explain it.')],
    tools: [fileTool],
  );

  if (toolResponse.toolCalls?.isNotEmpty == true) {
    for (final call in toolResponse.toolCalls ?? []) {
      print('Claude called: ${call.name}(${call.arguments})');
      final result = await fileTool.execute!(call.arguments);
      print('Result: $result');
    }
  } else {
    print('Response: ${toolResponse.content}');
  }

  // ─────────────────────────────────────────
  provider.dispose();
  print('\n✅ All Claude examples complete.');
}
