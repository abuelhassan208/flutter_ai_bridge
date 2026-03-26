import '../models/conversation.dart';

/// An abstract interface for storing and retrieving conversations.
///
/// This provides the foundation for the Persistence & Memory layer.
/// Implementations could use Hive, SQLite, SharedPreferences, or cloud databases.
abstract class StorageProvider {
  /// Saves a conversation to storage.
  Future<void> saveConversation(Conversation conversation);

  /// Loads a conversation by its unique ID.
  /// Returns null if not found.
  Future<Conversation?> loadConversation(String id);

  /// Loads all available conversations.
  /// Returns an empty list if none exist.
  Future<List<Conversation>> loadAllConversations();

  /// Deletes a conversation by its unique ID.
  Future<void> deleteConversation(String id);

  /// Closes any open resources or database connections.
  Future<void> dispose();
}
