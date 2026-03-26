# ai_bridge_storage_shared_prefs

SharedPreferences-based persistence for the [ai_bridge_core](https://pub.dev/packages/ai_bridge_core) framework — save and restore AI conversation history locally.

## Features

- Implements `StorageProvider` from `ai_bridge_core`
- Save/load/delete conversations via `SharedPreferences`
- JSON serialization with `FormatException` handling
- Lists all stored conversations

## Usage

```dart
import 'package:ai_bridge_storage_shared_prefs/ai_bridge_storage_shared_prefs.dart';

final storage = SharedPrefsStorage();
await storage.saveConversation(conversation);
final loaded = await storage.loadConversation('conv-id');
```

## License

MIT
