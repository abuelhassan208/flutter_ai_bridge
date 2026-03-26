# ai_bridge_openai

OpenAI provider for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — supports GPT-4o, GPT-4o-mini, Whisper (STT), TTS, DALL·E, and embeddings.

## Features

- Full OpenAI Chat Completions with streaming
- Tool/Function calling with automatic JSON parsing
- Image, audio, and document attachments
- Whisper speech-to-text and text-to-speech
- Token usage and cost tracking

## Usage

```dart
import 'package:ai_bridge_openai/ai_bridge_openai.dart';

final provider = OpenAIProvider(
  config: AIConfig(apiKey: 'sk-...', model: 'gpt-4o'),
);
final response = await provider.complete([AIMessage.user('Hello!')]);
```

## License

MIT
