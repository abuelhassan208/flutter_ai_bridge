# Flutter AI Bridge

A **modular, production-ready Flutter package** for unified AI provider integration — supports OpenAI, Google Gemini, Anthropic Claude, and local Ollama models with smart routing, agentic function calling, conversation persistence, cost control, RAG utilities, and ready-made UI widgets.

## ✨ Features

| Feature | Description |
|---|---|
| 🔌 **Multi-Provider** | OpenAI, Gemini, Claude, Ollama — one unified API |
| 🤖 **Agentic Pipelines** | `ConversationalAgent`, `SupervisorAgent`, `AIPipeline` memory routing |
| 🎨 **Generative UI (GenUI)** | Server-Driven declarative UI rendered natively from LLM Tool Calls |
| 🔄 **Intelligent Streaming** | Real-time token responses with `RetryOutputParser` for JSON structures |
| 🛡️ **Edge AI Fallback** | Seamless offline fallback to local Ollama when cloud fails |
| 📡 **Observability** | `AILogger` telemetry (tokens, latency, steps) |
| 💾 **Persistence** | Save/load conversation history via SharedPreferences |
| 💰 **Cost Control** | Token budgets, response caching, usage tracking |
| 🎤 **Audio IO** | Whisper (STT) and TTS built into OpenAIProvider |
| 📄 **RAG** | DocumentChunker, VectorStore, InMemoryVectorStore |
| 🖼️ **Multimodal** | Image, Audio, Video, Document attachments |

## 📦 Package Architecture

```
flutter_ai_bridge/
├── packages/
│   ├── ai_bridge_core         # Agents, Pipeline, Router, Parser, Telemetry, RAG
│   ├── ai_bridge_openai       # OpenAI GPT + Whisper + TTS
│   ├── ai_bridge_gemini       # Google Gemini
│   ├── ai_bridge_claude       # Anthropic Claude
│   ├── ai_bridge_ollama       # Local Ollama (Edge AI)
│   ├── ai_bridge_ui           # Flutter chat widgets (`AIChatWidget`)
│   ├── ai_bridge_genui        # Generative Server-Driven UI (`AIGeneratedView`)
│   ├── ai_bridge_storage_shared_prefs  # SharedPreferences persistence
│   └── flutter_ai_bridge      # Umbrella package (re-exports core, ui, genui)
```

## 🚀 Quick Start

```dart
import 'package:flutter_ai_bridge/flutter_ai_bridge.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';

// 1. Create providers
final openai = OpenAIProvider(
  config: AIConfig(apiKey: 'sk-...', model: 'gpt-4o'),
);
final gemini = GeminiProvider(
  config: AIConfig(apiKey: 'AI...', model: 'gemini-2.0-flash'),
);

// 2. Create the bridge with smart routing
final bridge = AIBridge(
  providers: [gemini, openai],
  strategy: RoutingStrategy.costOptimized,
  budget: TokenBudget(maxTokensPerDay: 100000),
);

// 3. Send a message
final response = await bridge.complete('Hello, AI!');
print(response.content);    // "Hello! How can I help?"
print(response.provider);   // "Gemini" (cheapest first)
print(response.usage);      // AIUsage(prompt: 5, completion: 12, total: 17)
```

## 🤖 Agentic Function Calling

```dart
final weatherTool = AITool(
  name: 'get_weather',
  description: 'Get weather for a location',
  parameters: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string', 'description': 'City name'}
    },
    'required': ['location']
  },
  execute: (args) async {
    return 'Sunny, 25°C in ${args['location']}';
  },
);

// ConversationManager will automatically:
//  1. Send the tool definition to the AI
//  2. Parse the AI's function call request
//  3. Execute your Dart callback
//  4. Send the result back to the AI
//  5. Return the final summarized answer
final response = await manager.send(convId, 'What is the weather in Cairo?',
  tools: [weatherTool],
);
```

## 🎨 UI Widget

```dart
AIChatWidget(
  provider: myProvider,
  systemPrompt: 'You are a helpful assistant.',
  theme: AIChatTheme.dark(),
  tools: [weatherTool],
)
```

## 📄 RAG (Retrieval-Augmented Generation)

```dart
final chunker = DocumentChunker(chunkSize: 500, chunkOverlap: 100);
final docs = chunker.splitText(longDocument);

// Persistent locally using local storage plugins
final vectorStore = PersistentVectorStore(
  embedder: openai,
  onSave: (val) async => saveToFile(val),
  onLoad: () async => loadFromFile(),
);
await vectorStore.addDocuments(docs);

final results = await vectorStore.similaritySearch('flutter widgets', limit: 3);
```

## 🎤 Audio

```dart
// Speech-to-Text (Whisper)
final text = await openai.speechToText(audioBytes, mimeType: 'audio/mp3');

// Text-to-Speech
final audioBytes = await openai.textToSpeech('Hello world', voice: 'nova');
```

## Comprehensive Examples

See the **[example/](example/)** directory for complete, copy-pasteable usage examples, including:
- Basic and streaming completions
- Tool and function calling
- Feature-specific capabilities (RAG, Pipelines, Agents, etc.)

## 📋 License

MIT License — see [LICENSE](LICENSE) for details.
