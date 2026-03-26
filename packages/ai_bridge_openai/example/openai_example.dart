import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';

void main() async {
  // 1. Configure the provider
  final config = AIConfig(apiKey: 'YOUR_OPENAI_API_KEY', model: 'gpt-4o');
  final provider = OpenAIProvider(config: config);

  // 2. Prepare conversation
  final messages = [
    AIMessage.system('You are a helpful assistant.'),
    AIMessage.user('Hello, who are you?'),
  ];

  // 3. Make the API call
  try {
    print('Sending request to OpenAI...');
    final response = await provider.complete(messages);
    print('Response: ${response.content}');
  } on AIError catch (e) {
    print('AI Error occurred: $e');
  }
}
