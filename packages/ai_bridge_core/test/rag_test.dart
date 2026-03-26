import 'package:test/test.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';

void main() {
  group('DocumentChunker', () {
    test('splits text into chunks of correct size', () {
      final chunker = DocumentChunker(chunkSize: 10, chunkOverlap: 0);
      final docs = chunker.splitText('0123456789ABCDEF');
      expect(docs.length, 2);
      expect(docs[0].content, '0123456789');
      expect(docs[1].content, 'ABCDEF');
    });

    test('applies overlap between chunks', () {
      final chunker = DocumentChunker(chunkSize: 10, chunkOverlap: 5);
      final docs = chunker.splitText('A' * 20);
      // With size=10 overlap=5, step=5: chunks at 0-10, 5-15, 10-20
      expect(docs.length, 3);
    });

    test('returns empty list for empty text', () {
      final chunker = DocumentChunker();
      expect(chunker.splitText(''), isEmpty);
    });

    test('preserves metadata in each chunk', () {
      final chunker = DocumentChunker(chunkSize: 100, chunkOverlap: 0);
      final docs =
          chunker.splitText('Hello world', metadata: {'source': 'test'});
      expect(docs.first.metadata['source'], 'test');
      expect(docs.first.metadata['start_index'], 0);
    });

    test('handles text shorter than chunk size', () {
      final chunker = DocumentChunker(chunkSize: 1000, chunkOverlap: 0);
      final docs = chunker.splitText('Short');
      expect(docs.length, 1);
      expect(docs.first.content, 'Short');
    });

    test('prevents infinite loop when overlap >= size', () {
      final chunker = DocumentChunker(chunkSize: 5, chunkOverlap: 5);
      final docs = chunker.splitText('Hello world');
      // Should produce at most 1 chunk and stop
      expect(docs.length, 1);
    });
  });

  group('AIDocument', () {
    test('cosine similarity with matching embeddings', () {
      final doc = AIDocument(
        content: 'test',
        embedding: [1.0, 0.0, 0.0],
      );
      final similarity = doc.similarityTo([1.0, 0.0, 0.0]);
      expect(similarity, closeTo(1.0, 0.001));
    });

    test('cosine similarity with orthogonal embeddings', () {
      final doc = AIDocument(
        content: 'test',
        embedding: [1.0, 0.0, 0.0],
      );
      final similarity = doc.similarityTo([0.0, 1.0, 0.0]);
      expect(similarity, closeTo(0.0, 0.001));
    });

    test('similarity returns 0 with no embedding', () {
      final doc = AIDocument(content: 'test');
      expect(doc.similarityTo([1.0, 2.0]), 0.0);
    });

    test('similarity returns 0 with mismatched lengths', () {
      final doc = AIDocument(content: 'test', embedding: [1.0, 2.0]);
      expect(doc.similarityTo([1.0]), 0.0);
    });
  });

  group('InMemoryVectorStore', () {
    test('addDocuments generates embeddings', () async {
      final store = InMemoryVectorStore(embedder: _MockEmbedder());
      await store.addDocuments([AIDocument(content: 'test')]);
      expect(store.documents.length, 1);
      expect(store.documents.first.embedding, isNotNull);
    });

    test('addDocuments preserves existing embeddings', () async {
      final store = InMemoryVectorStore(embedder: _MockEmbedder());
      final preEmbedded = AIDocument(content: 'test', embedding: [9.9]);
      await store.addDocuments([preEmbedded]);
      expect(store.documents.first.embedding, [9.9]); // Unchanged
    });

    test('similaritySearch returns results in order', () async {
      final store = InMemoryVectorStore(embedder: _MockEmbedder());
      await store.addDocuments([
        AIDocument(content: 'A', embedding: [1.0, 0.0]),
        AIDocument(content: 'B', embedding: [0.0, 1.0]),
        AIDocument(content: 'C', embedding: [0.5, 0.5]),
      ]);

      // Query for [1.0, 0.0] — A should be first
      final results = await store.similaritySearch('query', limit: 2);
      expect(results.length, 2);
    });

    test('similaritySearch returns empty for empty store', () async {
      final store = InMemoryVectorStore(embedder: _MockEmbedder());
      final results = await store.similaritySearch('anything');
      expect(results, isEmpty);
    });

    test('clear removes all documents', () async {
      final store = InMemoryVectorStore(embedder: _MockEmbedder());
      await store.addDocuments([AIDocument(content: 'test')]);
      await store.clear();
      expect(store.documents, isEmpty);
    });
  });
}

/// Mock embedder for testing vector store.
class _MockEmbedder implements AIEmbeddingProvider {
  @override
  Future<List<double>> embed(String text) async {
    // Simple deterministic "embedding" based on text length
    return [text.length.toDouble(), text.length * 0.5];
  }
}
