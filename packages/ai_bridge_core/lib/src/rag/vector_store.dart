import 'ai_document.dart';

/// Abstract interface for a Vector Database/Store used in RAG.
///
/// Can be implemented in-memory, or wrapped around specialized
/// local DBs (ObjectBox, Isar) or remote DBs (Pinecone, Chroma).
abstract class VectorStore {
  /// Adds documents to the store.
  /// Implementation should compute embeddings if the document doesn't have them yet.
  Future<void> addDocuments(List<AIDocument> documents);

  /// Searches for the most similar documents to the given query.
  ///
  /// [query] The text query to search for.
  /// [limit] Maximum number of documents to return.
  Future<List<AIDocument>> similaritySearch(String query, {int limit = 4});

  /// Deletes all documents in this store.
  Future<void> clear();
}
