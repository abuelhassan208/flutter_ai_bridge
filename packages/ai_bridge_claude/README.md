# ai_bridge_claude

Anthropic Claude provider for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — supports Claude 3.5 Sonnet, Haiku, and Opus.

## Features

- Full Claude Messages API with streaming
- Tool use (function calling)
- System prompt via dedicated field
- Image and document (PDF) attachments
- Proper Anthropic header handling

## Usage

```dart
import 'package:ai_bridge_claude/ai_bridge_claude.dart';

final provider = ClaudeProvider(
  config: AIConfig(apiKey: 'sk-ant-...', model: 'claude-3-5-sonnet-20241022'),
);
final response = await provider.complete([AIMessage.user('Hello!')]);
```

## License

MIT
