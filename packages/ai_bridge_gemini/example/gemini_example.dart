/// Comprehensive usage examples for `ai_bridge_gemini`.
///
/// Demonstrates:
/// - Basic chat completion with system instruction
/// - Streaming responses
/// - Function declarations (tool calling)
/// - Embeddings
library;

import 'dart:io';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';

void main() async {
  // ─────────────────────────────────────────
  // Setup
  // ─────────────────────────────────────────
  final provider = GeminiProvider(
    config: AIConfig(
      apiKey: Platform.environment['GEMINI_API_KEY'] ?? 'AIza...',
      model: 'gemini-2.0-flash',
    ),
  );

  // ─────────────────────────────────────────
  // 1. Basic Completion + System Instruction
  // ─────────────────────────────────────────
  print('── 1. Basic Completion ──');
  final response = await provider.complete([
    AIMessage.system('You are a concise coding assistant.'),
    AIMessage.user('Explain async/await in Dart in 2 sentences.'),
  ]);
  print('Response: ${response.content}');
  print('Tokens: ${response.usage.totalTokens}');

  // ─────────────────────────────────────────
  // 2. Streaming
  // ─────────────────────────────────────────
  print('\n── 2. Streaming ──');
  final stream = provider.completeStream([
    AIMessage.user('List 3 benefits of using Flutter.'),
  ]);

  await for (final chunk in stream) {
    stdout.write(chunk.text);
  }
  print('');

  // ─────────────────────────────────────────
  // 3. Function Declarations (Tool Calling)
  // ─────────────────────────────────────────
  print('\n── 3. Function Declarations ──');
  final searchTool = AITool(
    name: 'search_database',
    description: 'Search the product database by keyword',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The search keyword',
        },
        'limit': {
          'type': 'integer',
          'description': 'Max number of results',
        },
      },
      'required': ['query'],
    },
    execute: (args) async =>
        '{"results": [{"name": "Widget A", "price": 9.99}]}',
  );

  final toolResponse = await provider.complete(
    [AIMessage.user('Search for widgets in our database')],
    tools: [searchTool],
  );

  if (toolResponse.toolCalls?.isNotEmpty == true) {
    for (final call in toolResponse.toolCalls ?? []) {
      print('Gemini called: ${call.name}(${call.arguments})');
    }
  } else {
    print('Response: ${toolResponse.content}');
  }

  // ─────────────────────────────────────────
  // 4. Embeddings
  // ─────────────────────────────────────────
  print('\n── 4. Embeddings ──');
  final embedding = await provider.embed('Semantic search with Gemini');
  print('Embedding dimensions: ${embedding.length}');

  // ─────────────────────────────────────────
  provider.dispose();
  print('\n✅ All Gemini examples complete.');
}
