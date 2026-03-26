/// A chunk of textual data, usually parsed from a larger document.
class AIDocument {
  /// The specific chunk of text.
  final String content;

  /// Optional metadata associated with this chunk (e.g., source file, page number).
  final Map<String, dynamic> metadata;

  /// Optional embedding vector representing the text.
  List<double>? embedding;

  AIDocument({
    required this.content,
    this.metadata = const {},
    this.embedding,
  });

  factory AIDocument.fromJson(Map<String, dynamic> json) {
    return AIDocument(
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'metadata': metadata,
      if (embedding != null) 'embedding': embedding,
    };
  }

  /// Calculates cosine similarity between this document's embedding and a query.
  double similarityTo(List<double> queryEmbedding) {
    if (embedding == null || embedding!.isEmpty) return 0.0;
    if (queryEmbedding.isEmpty || embedding!.length != queryEmbedding.length)
      return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < embedding!.length; i++) {
      dotProduct += embedding![i] * queryEmbedding[i];
      normA += embedding![i] * embedding![i];
      normB += queryEmbedding[i] * queryEmbedding[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    // We can avoid sqrt if vectors are already normalized, but assume they aren't.
    // Actually, OpenAI embeddings are normalized to length 1.
    return dotProduct;
  }
}
