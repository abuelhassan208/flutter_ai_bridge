/// Comprehensive usage examples for `ai_bridge_openai`.
///
/// Demonstrates:
/// - Basic chat completion
/// - Streaming responses
/// - Tool/Function calling
/// - Whisper speech-to-text
/// - Text-to-speech (TTS)
/// - Embeddings
library;

import 'dart:io';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';

void main() async {
  // ─────────────────────────────────────────
  // Setup
  // ─────────────────────────────────────────
  final provider = OpenAIProvider(
    config: AIConfig(
      apiKey: Platform.environment['OPENAI_API_KEY'] ?? 'sk-...',
      model: 'gpt-4o-mini',
    ),
  );

  // ─────────────────────────────────────────
  // 1. Basic Completion
  // ─────────────────────────────────────────
  print('── 1. Basic Completion ──');
  final response = await provider.complete([
    AIMessage.system('You are a helpful assistant.'),
    AIMessage.user('What is Flutter in one sentence?'),
  ]);
  print('Response: ${response.content}');
  print('Tokens: ${response.usage.totalTokens}');
  print('Latency: ${response.latency.inMilliseconds}ms');

  // ─────────────────────────────────────────
  // 2. Streaming Response
  // ─────────────────────────────────────────
  print('\n── 2. Streaming ──');
  final stream = provider.completeStream([
    AIMessage.user('Count from 1 to 5, one number per line.'),
  ]);

  await for (final chunk in stream) {
    stdout.write(chunk.text); // Print tokens as they arrive
  }
  print(''); // Newline

  // ─────────────────────────────────────────
  // 3. Tool / Function Calling
  // ─────────────────────────────────────────
  print('\n── 3. Tool Calling ──');
  final calculatorTool = AITool(
    name: 'calculate',
    description: 'Perform a math calculation',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {
          'type': 'string',
          'description': 'The math expression to evaluate',
        },
      },
      'required': ['expression'],
    },
    execute: (args) async {
      // In production, use a real math parser
      return '{"result": 42}';
    },
  );

  final toolResponse = await provider.complete(
    [AIMessage.user('What is 6 times 7?')],
    tools: [calculatorTool],
  );
  print('Tool response: ${toolResponse.content}');

  // Check if the model made a tool call
  if (toolResponse.toolCalls?.isNotEmpty == true) {
    for (final call in toolResponse.toolCalls ?? []) {
      print('Tool called: ${call.name}(${call.arguments})');
      final result = await calculatorTool.execute!(call.arguments);
      print('Tool result: $result');
    }
  }

  // ─────────────────────────────────────────
  // 4. Speech-to-Text (Whisper)
  // ─────────────────────────────────────────
  print('\n── 4. Speech-to-Text ──');
  // final audioFile = File('audio.mp3');
  // if (audioFile.existsSync()) {
  //   final transcript = await provider.speechToText(
  //     audioFile.readAsBytesSync(),
  //     mimeType: 'audio/mp3',
  //   );
  //   print('Transcript: $transcript');
  // }
  print('(Uncomment the code above and provide an audio file to test.)');

  // ─────────────────────────────────────────
  // 5. Embeddings
  // ─────────────────────────────────────────
  print('\n── 5. Embeddings ──');
  final embedding = await provider.embed('Flutter is a UI toolkit');
  print('Embedding dimensions: ${embedding.length}');
  print('First 5 values: ${embedding.take(5).toList()}');

  // ─────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────
  provider.dispose();
  print('\n✅ All OpenAI examples complete.');
}
