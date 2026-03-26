# ai_bridge_ollama

Local Ollama provider for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — run AI models locally for offline/edge computing using Llama, Mistral, and more.

## Features

- Full Ollama Chat API with streaming
- Tool/Function calling support
- Embeddings via local models
- Custom `baseUrl` for remote Ollama instances
- Image attachment support
- Zero cloud dependency — fully offline Edge AI

## Usage

```dart
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';

final provider = OllamaProvider(
  config: AIConfig(apiKey: '', model: 'llama3.2'),
);
final response = await provider.complete([AIMessage.user('Hello!')]);
```

## Comprehensive Examples

See the **[example/](example/)** directory for complete, copy-pasteable usage examples, including:
- Local offline completions and streaming
- Edge AI fallback pattern with AIRouter

## License

MIT
