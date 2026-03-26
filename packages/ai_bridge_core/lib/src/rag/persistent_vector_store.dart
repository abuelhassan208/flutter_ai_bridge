import 'dart:convert';
import '../providers/ai_embedding_provider.dart';
import 'ai_document.dart';
import 'in_memory_vector_store.dart';

/// A function type that loads a serialized JSON string containing vectors.
/// For example, reading from a file using dart:io or shared_preferences.
typedef VectorLoader = Future<String?> Function();

/// A function type that saves a serialized JSON string containing vectors.
/// For example, writing to a file using dart:io or shared_preferences.
typedef VectorSaver = Future<void> Function(String json);

/// An extension of [InMemoryVectorStore] that persists documents and their 
/// embeddings locally using user-provided loader and saver callbacks.
///
/// This provides a pure-Dart Local RAG Vector Database capable of 
/// running anywhere without native SQLite dependencies.
class PersistentVectorStore extends InMemoryVectorStore {
  final VectorLoader loader;
  final VectorSaver saver;
  bool _isInit = false;

  PersistentVectorStore({
    required AIEmbeddingProvider embedder,
    required this.loader,
    required this.saver,
  }) : super(embedder: embedder);

  /// Must be called to load existing data before searching or adding.
  Future<void> init() async {
    if (_isInit) return;
    
    final rawJson = await loader();
    if (rawJson != null && rawJson.trim().isNotEmpty) {
      final List<dynamic> jsonList = jsonDecode(rawJson);
      final docs = jsonList
          .map((e) => AIDocument.fromJson(e as Map<String, dynamic>))
          .toList();
      documents.clear();
      documents.addAll(docs);
    }
    _isInit = true;
  }

  @override
  Future<void> addDocuments(List<AIDocument> docs) async {
    if (!_isInit) await init();
    await super.addDocuments(docs);
    await _saveState();
  }

  @override
  Future<List<AIDocument>> similaritySearch(String query, {int limit = 4}) async {
    if (!_isInit) await init();
    return super.similaritySearch(query, limit: limit);
  }

  @override
  Future<void> clear() async {
    await super.clear();
    await _saveState();
  }

  Future<void> _saveState() async {
    final jsonList = documents.map((e) => e.toJson()).toList();
    final rawJson = jsonEncode(jsonList);
    await saver(rawJson);
  }
}
