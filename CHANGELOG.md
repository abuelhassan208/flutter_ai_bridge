# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-26

### Added

#### Core (`ai_bridge_core`)
- `AIProvider` abstract interface with `complete`, `completeStream`, `embed`, `estimateTokens`.
- `AIMessage`, `AIRole`, `Conversation` unified data models with JSON serialization.
- `AIConfig` with `maxAttachmentBytes` data constraint.
- `AIResponse` and `AIStreamChunk` with `toolCalls` support.
- `AITool` and `AIToolCall` models for agentic function calling.
- `AIRouter` with `RoutingStrategy` (primary, roundRobin, costOptimized) and streaming fallback.
- `FallbackChain`, `CircuitBreaker`, `RetryHandler` resilience patterns.
- `ConversationManager` with context trimming, storage sync, and autonomous tool execution loop.
- `TokenTracker`, `TokenBudget`, `ResponseCache` cost control utilities.
- `StorageProvider` abstract persistence interface.
- `AIAudioProvider` interface for Speech-to-Text and Text-to-Speech.
- `AIDocument`, `DocumentChunker`, `VectorStore`, `InMemoryVectorStore` RAG utilities.
- 9-class `AIError` sealed hierarchy with `isRetryable`.
- `AIAttachment` with `image`, `audio`, `video`, `document`, `file` types.

#### Providers
- **`ai_bridge_openai`** — GPT-4o, GPT-4, GPT-3.5 with vision, function calling, Whisper STT, TTS.
- **`ai_bridge_gemini`** — Gemini 2.0 Flash, 1.5 Pro with vision, audio, video, functionDeclarations.
- **`ai_bridge_claude`** — Claude Sonnet, Haiku with vision, document attachments.
- **`ai_bridge_ollama`** — Local Ollama (Llama 3.2, etc.) with vision and embeddings.

#### UI (`ai_bridge_ui`)
- `AIChatWidget` — complete chat interface with streaming, typing indicator, tool support.
- `MessageBubble` — themed message component.
- `AIInputBar` — input bar with send button.
- `AIChatTheme` — dark/light theme system.

#### Storage (`ai_bridge_storage_shared_prefs`)
- `SharedPreferencesStorageProvider` — persistent conversation history.

#### Umbrella (`flutter_ai_bridge`)
- Re-exports `ai_bridge_core` + `ai_bridge_ui` for single-import convenience.
- Example Flutter application with multi-provider chat, conversation history drawer, and weather tool demo.
