import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';

/// A [StorageProvider] implementation that uses `SharedPreferences` to persist
/// AI conversations locally on the device.
class SharedPreferencesStorageProvider implements StorageProvider {
  static const String _keyPrefix = 'ai_bridge_conv_';
  final SharedPreferences _prefs;

  SharedPreferencesStorageProvider._(this._prefs);

  /// Initializes and returns the storage provider.
  static Future<SharedPreferencesStorageProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStorageProvider._(prefs);
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    final jsonStr = jsonEncode(conversation.toJson());
    await _prefs.setString('$_keyPrefix${conversation.id}', jsonStr);
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final jsonStr = _prefs.getString('$_keyPrefix$id');
    if (jsonStr == null) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Conversation.fromJson(map);
    } catch (e) {
      // Return null or throw error depending on strictness
      return null;
    }
  }

  @override
  Future<List<Conversation>> loadAllConversations() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    final conversations = <Conversation>[];

    for (final key in keys) {
      final jsonStr = _prefs.getString(key);
      if (jsonStr != null) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          conversations.add(Conversation.fromJson(map));
        } on FormatException catch (_) {
          // Skip corrupted JSON entries
        }
      }
    }

    // Sort by updated time, newest first
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  @override
  Future<void> deleteConversation(String id) async {
    await _prefs.remove('$_keyPrefix$id');
  }

  @override
  Future<void> dispose() async {
    // SharedPreferences doesn't require explicit disposal
  }
}
