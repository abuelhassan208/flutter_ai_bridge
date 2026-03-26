import 'ai_document.dart';

/// Splits long text into manageable chunks for vector embeddings.
class DocumentChunker {
  /// The maximum size of each chunk (in characters).
  final int chunkSize;

  /// The number of overlapping characters between consecutive chunks.
  ///
  /// Overlap preserves context across chunk boundaries.
  final int chunkOverlap;

  DocumentChunker({
    this.chunkSize = 1000,
    this.chunkOverlap = 200,
  });

  /// Splits a single string of text into multiple [AIDocument] chunks.
  ///
  /// Metadata is injected into each generated chunk.
  List<AIDocument> splitText(String text,
      {Map<String, dynamic> metadata = const {}}) {
    final docs = <AIDocument>[];

    if (text.isEmpty) return docs;

    // Simple character-based sliding window splitting
    for (int i = 0; i < text.length; i += (chunkSize - chunkOverlap)) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      final chunk = text.substring(i, end).trim();

      if (chunk.isNotEmpty) {
        docs.add(AIDocument(
          content: chunk,
          metadata: {
            ...metadata,
            'start_index': i,
            'end_index': end,
          },
        ));
      }

      // Prevent infinite loop if overlap >= size
      if (chunkSize - chunkOverlap <= 0) break;
      if (end >= text.length) break;
    }

    return docs;
  }
}
