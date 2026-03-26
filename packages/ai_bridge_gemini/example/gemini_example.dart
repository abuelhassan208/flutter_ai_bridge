import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';

void main() async {
  final config =
      AIConfig(apiKey: 'YOUR_GEMINI_API_KEY', model: 'gemini-1.5-pro');
  final provider = GeminiProvider(config: config);

  final messages = [
    AIMessage.system('You are an expert coder.'),
    AIMessage.user('Write a hello world in Dart.'),
  ];

  try {
    print('Sending request to Gemini...');
    final response = await provider.complete(messages);
    print('Response: ${response.content}');
  } on AIError catch (e) {
    print('AI Error occurred: $e');
  }
}
