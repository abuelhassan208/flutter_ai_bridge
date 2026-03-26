/// Abstract interface for providers that support text embeddings.
///
/// This follows the Interface Segregation Principle (ISP) —
/// only providers that actually support embeddings implement this.
abstract class AIEmbeddingProvider {
  /// Generates embeddings for the given text.
  ///
  /// Returns a list of doubles representing the vector embedding.
  Future<List<double>> embed(String text);
}
