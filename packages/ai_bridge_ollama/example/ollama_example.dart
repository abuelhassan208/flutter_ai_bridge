/// Comprehensive usage examples for `ai_bridge_ollama`.
///
/// Demonstrates:
/// - Local model completion (fully offline)
/// - Streaming responses
/// - Embeddings via local models
/// - Edge AI fallback pattern with AIRouter
library;

import 'dart:io';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';

void main() async {
  // ─────────────────────────────────────────
  // Setup — requires Ollama running locally
  // Install: https://ollama.ai
  // Pull a model: ollama pull llama3.2
  // ─────────────────────────────────────────
  final provider = OllamaProvider(
    config: AIConfig(
      apiKey: '', // Ollama doesn't need an API key
      model: 'llama3.2',
      // Custom base URL (default: http://localhost:11434)
      // baseUrl: 'http://192.168.1.100:11434',
    ),
  );

  // ─────────────────────────────────────────
  // 1. Basic Completion (Offline!)
  // ─────────────────────────────────────────
  print('── 1. Local Completion ──');
  final response = await provider.complete([
    AIMessage.system('You are a helpful assistant running locally.'),
    AIMessage.user('Explain what Edge AI means in 2 sentences.'),
  ]);
  print('Response: ${response.content}');
  print('Model: ${provider.model}');
  print('Latency: ${response.latency.inMilliseconds}ms');

  // ─────────────────────────────────────────
  // 2. Streaming
  // ─────────────────────────────────────────
  print('\n── 2. Streaming ──');
  final stream = provider.completeStream([
    AIMessage.user('What are the benefits of running AI locally?'),
  ]);

  await for (final chunk in stream) {
    stdout.write(chunk.text);
  }
  print('');

  // ─────────────────────────────────────────
  // 3. Embeddings (Local)
  // ─────────────────────────────────────────
  print('\n── 3. Local Embeddings ──');
  final embedding = await provider.embed('Flutter AI Bridge');
  print('Embedding dimensions: ${embedding.length}');
  print('First 3 values: ${embedding.take(3).toList()}');

  // ─────────────────────────────────────────
  // 4. Edge AI Fallback Pattern
  // ─────────────────────────────────────────
  print('\n── 4. Fallback Pattern ──');
  // In production, combine with a cloud provider:
  //
  // final router = AIRouter(providers: [cloudProvider, ollamaProvider]);
  //
  // The router will try the cloud provider first. If it fails
  // (network error, rate limit), it automatically falls back to
  // the local Ollama instance — zero downtime!
  //
  // final selected = router.routeRequest(
  //   strategy: RoutingStrategy.fallback,
  //   capability: AICapability.chat,
  // );
  print('Use AIRouter with FallbackChain for seamless offline fallback.');

  // ─────────────────────────────────────────
  provider.dispose();
  print('\n✅ All Ollama examples complete. (100% offline!)');
}
