import 'package:ai_bridge_core/ai_bridge_core.dart';

void main() async {
  print('Loading AI Router...');

  // Create a config
  final config = const AIConfig(apiKey: 'YOUR_API_KEY', model: 'gpt-4o');

  // Note: This is an abstract core package.
  // In a real app, you would register a concrete provider (e.g., OpenAIProvider)
  final router = AIRouter(providers: []);

  print(
      'Router created with ${router.providers.length} default strategies using $config.');
  print('To use it, add ai_bridge_openai or ai_bridge_gemini dependencies.');
}
