import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_claude/ai_bridge_claude.dart';

void main() async {
  final config = AIConfig(
      apiKey: 'YOUR_ANTHROPIC_API_KEY', model: 'claude-3-opus-20240229');
  final provider = ClaudeProvider(config: config);

  final messages = [
    AIMessage.system('Respond only with a single haiku.'),
    AIMessage.user('Tell me about the ocean.'),
  ];

  try {
    print('Sending request to Claude...');
    final response = await provider.complete(messages);
    print('Response: ${response.content}');
  } on AIError catch (e) {
    print('AI Error occurred: $e');
  }
}
