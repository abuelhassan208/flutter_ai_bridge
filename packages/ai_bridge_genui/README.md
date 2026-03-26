# ai_bridge_genui

Server-Driven Generative UI framework for [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) — dynamically render native Flutter widgets from LLM tool calls using strict JSON Schema.

## Features

- `GenUIWidgetRegistry` — map string names to Flutter `WidgetBuilder` functions
- `GenUITool` — exposes the widget registry to the LLM as a callable tool with JSON Schema validation
- `AIGeneratedView` — intercepts AI tool calls and renders native Flutter widgets inline

## Usage

```dart
import 'package:ai_bridge_genui/ai_bridge_genui.dart';

// Register your widgets
final registry = GenUIWidgetRegistry();
registry.register(RegisteredGenUIWidget(
  name: 'weather_card',
  description: 'A weather forecast card',
  parametersSchema: {'type': 'object', 'properties': {'city': {'type': 'string'}}},
  builder: (ctx, data) => Text('Weather in ${data["city"]}'),
));

// Give the registry to your agent as a tool
final tool = GenUITool(registry: registry);
```

## License

MIT
