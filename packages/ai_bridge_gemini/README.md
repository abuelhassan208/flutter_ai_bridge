# ai_bridge_gemini

Google Gemini provider for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — supports Gemini 2.0 Flash, Pro, and embeddings.

## Features

- Full Gemini Chat Completions with streaming
- Function declarations (tool calling)
- System instruction support
- Image and document attachments
- Embeddings via `text-embedding-004`

## Usage

```dart
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';

final provider = GeminiProvider(
  config: AIConfig(apiKey: 'AI...', model: 'gemini-2.0-flash'),
);
final response = await provider.complete([AIMessage.user('Hello!')]);
```

## License

MIT
