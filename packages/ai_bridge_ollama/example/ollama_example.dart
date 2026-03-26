import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';

void main() async {
  // Model name should be something pulled locally e.g. 'llama3.1'
  final config = AIConfig(apiKey: '', model: 'llama3.1');

  // Custom baseUrl is optional, defaults to http://localhost:11434/api
  final provider = OllamaProvider(config: config);

  final messages = [
    AIMessage.user('What is 2+2?'),
  ];

  try {
    print('Sending request to local Ollama model...');
    final response = await provider.complete(messages);
    print('Response: ${response.content}');
  } on AIError catch (e) {
    print('AI Error occurred: $e');
  }
}
