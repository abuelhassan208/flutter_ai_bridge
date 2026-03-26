import 'dart:async';

import '../models/ai_response.dart';

/// Callback for each received chunk.
typedef OnChunkCallback = void Function(AIStreamChunk chunk);

/// Callback when streaming completes.
typedef OnCompleteCallback = void Function(String fullText, AIUsage? usage);

/// Callback for stream errors.
typedef OnStreamErrorCallback = void Function(Object error);

/// Manages streaming AI responses with unified handling.
///
/// Provides utilities for:
/// - Accumulating text from chunks
/// - Timeout handling
/// - Error recovery
/// - Completion callbacks
class StreamHandler {
  /// Timeout for the entire stream.
  final Duration? timeout;

  StreamHandler({this.timeout});

  /// Processes a stream of chunks and returns the accumulated text.
  ///
  /// Provides callbacks for real-time updates.
  Future<String> process(
    Stream<AIStreamChunk> stream, {
    OnChunkCallback? onChunk,
    OnCompleteCallback? onComplete,
    OnStreamErrorCallback? onError,
  }) async {
    final buffer = StringBuffer();
    AIUsage? finalUsage;

    try {
      final effectiveStream =
          timeout != null ? stream.timeout(timeout!) : stream;

      await for (final chunk in effectiveStream) {
        buffer.write(chunk.text);
        onChunk?.call(chunk);

        if (chunk.isComplete) {
          finalUsage = chunk.usage;
        }
      }
    } catch (e) {
      onError?.call(e);
      if (buffer.isEmpty) rethrow;
      // If we have partial content, return it
    }

    final fullText = buffer.toString();
    onComplete?.call(fullText, finalUsage);
    return fullText;
  }

  /// Converts a stream of chunks into a stream of accumulated text.
  ///
  /// Each emission contains the full text received so far.
  Stream<String> accumulate(Stream<AIStreamChunk> stream) async* {
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(chunk.text);
      yield buffer.toString();
    }
  }
}
