import 'ai_document.dart';
import 'vector_store.dart';
import '../providers/ai_embedding_provider.dart';

/// A simple, local, list-backed Vector Store.
///
/// Automatically generates embeddings using the provided [AIProvider]
/// and performs brute-force cosine similarity searches in runtime memory.
/// Suitable for small-scale RAG on device without external dependencies.
class InMemoryVectorStore implements VectorStore {
  /// The provider used to generate text embeddings.
  final AIEmbeddingProvider embedder;

  final List<AIDocument> _documents = [];

  InMemoryVectorStore({required this.embedder});

  /// Returns all currently stored documents.
  List<AIDocument> get documents => List.unmodifiable(_documents);

  @override
  Future<void> addDocuments(List<AIDocument> docs) async {
    for (final doc in docs) {
      if (doc.embedding == null) {
        doc.embedding = await embedder.embed(doc.content);
      }
      _documents.add(doc);
    }
  }

  @override
  Future<List<AIDocument>> similaritySearch(String query,
      {int limit = 4}) async {
    if (_documents.isEmpty) return [];

    // Generate embedding for the search query
    final queryEmbedding = await embedder.embed(query);

    // Calculate similarities
    final scored = _documents.map((doc) {
      return MapEntry(doc, doc.similarityTo(queryEmbedding));
    }).toList();

    // Sort descending by similarity score
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Return top K
    return scored.take(limit).map((e) => e.key).toList();
  }

  @override
  Future<void> clear() async {
    _documents.clear();
  }
}
