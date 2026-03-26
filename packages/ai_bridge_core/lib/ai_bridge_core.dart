/// Core models, interfaces, and utilities for Flutter AI Bridge.
///
/// This package provides the foundational abstractions for integrating
/// AI providers into Flutter applications with a unified API.
library ai_bridge_core;

// Models
export 'src/models/ai_message.dart';
export 'src/models/ai_response.dart';
export 'src/models/ai_config.dart';
export 'src/models/conversation.dart';
export 'src/models/ai_capability.dart';
export 'src/models/ai_tool.dart';

// Provider Interface
export 'src/providers/ai_provider.dart';

// 2. Agents & Pipelines (Agentic UX)
export 'src/agents/ai_agent.dart';
export 'src/agents/ai_pipeline.dart';
export 'src/agents/conversational_agent.dart';
export 'src/agents/supervisor_agent.dart';
export 'src/agents/agent_memory.dart';

// Observability
export 'src/observability/ai_logger.dart';
export 'src/observability/console_logger.dart';

// Parsers
export 'src/parsers/output_parser.dart';
export 'src/parsers/json_output_parser.dart';
export 'src/parsers/retry_output_parser.dart';

// Errors
export 'src/errors/ai_error.dart';
export 'src/errors/retry_handler.dart';
export 'src/errors/circuit_breaker.dart';

// Router
export 'src/router/ai_router.dart';
export 'src/router/fallback_chain.dart';
export 'src/router/routing_strategy_handler.dart';

// Conversation
export 'src/conversation/conversation_manager.dart';
export 'src/conversation/token_tracker.dart';
export 'src/conversation/storage_provider.dart';
export 'src/conversation/tool_execution_loop.dart';

// Cost
export 'src/cost/token_budget.dart';
export 'src/cost/response_cache.dart';

// Streaming
export 'src/streaming/stream_handler.dart';

// Audio
export 'src/audio/audio_provider.dart';

// Providers (additional interfaces)
export 'src/providers/ai_embedding_provider.dart';

// Utils
export 'src/utils/cancellation_token.dart';

// RAG
export 'src/rag/ai_document.dart';
export 'src/rag/vector_store.dart';
export 'src/rag/document_chunker.dart';
export 'src/rag/in_memory_vector_store.dart';
export 'src/rag/persistent_vector_store.dart';

// Bridge (main entry point)
export 'src/ai_bridge.dart';
