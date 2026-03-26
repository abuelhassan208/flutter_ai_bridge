# ai_bridge_ui

Pre-built Flutter chat widgets for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — drop-in `AIChatWidget` with streaming, typing indicators, and theming.

## Features

- `AIChatWidget` — full chat interface with message bubbles
- Streaming text animation
- Typing indicator
- Dark mode support via `AIChatTheme`
- Tool calling integration

## Usage

```dart
import 'package:ai_bridge_ui/ai_bridge_ui.dart';

AIChatWidget(
  provider: myProvider,
  systemPrompt: 'You are a helpful assistant.',
  theme: AIChatTheme.dark(),
)
```

## License

MIT
