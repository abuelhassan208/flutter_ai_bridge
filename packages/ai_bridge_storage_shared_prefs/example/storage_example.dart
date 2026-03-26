/// Comprehensive usage examples for `ai_bridge_storage_shared_prefs`.
///
/// Demonstrates:
/// - Creating and saving a conversation
/// - Loading a conversation by ID
/// - Listing all saved conversations
/// - Deleting a conversation
///
/// Note: SharedPreferences requires a Flutter environment.
/// This example shows the API patterns; run it inside a Flutter app.
library;

import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_storage_shared_prefs/ai_bridge_storage_shared_prefs.dart';

void main() async {
  // ─────────────────────────────────────────
  // Setup
  // ─────────────────────────────────────────
  final storage = await SharedPreferencesStorageProvider.create();

  // ─────────────────────────────────────────
  // 1. Create & Save a Conversation
  // ─────────────────────────────────────────
  print('── 1. Save Conversation ──');
  final conversation = Conversation(id: 'conv-001');
  conversation.addMessage(AIMessage.system('You are a helpful assistant.'));
  conversation.addMessage(AIMessage.user('Hello!'));
  conversation.addMessage(AIMessage.assistant('Hi! How can I help you?'));

  await storage.saveConversation(conversation);
  print('Saved conversation: ${conversation.id}');
  print('Messages: ${conversation.activeMessages.length}');

  // ─────────────────────────────────────────
  // 2. Load a Conversation
  // ─────────────────────────────────────────
  print('\n── 2. Load Conversation ──');
  final loaded = await storage.loadConversation('conv-001');
  if (loaded != null) {
    print('Loaded: ${loaded.id}');
    print('Messages: ${loaded.activeMessages.length}');
    for (final msg in loaded.activeMessages) {
      print('  [${msg.role}] ${msg.content.substring(0, 30)}...');
    }
  } else {
    print('Conversation not found.');
  }

  // ─────────────────────────────────────────
  // 3. List All Conversations
  // ─────────────────────────────────────────
  print('\n── 3. List All ──');
  final all = await storage.loadAllConversations();
  print('Total conversations: ${all.length}');
  for (final conv in all) {
    print('  - ${conv.id} (${conv.activeMessages.length} messages)');
  }

  // ─────────────────────────────────────────
  // 4. Delete a Conversation
  // ─────────────────────────────────────────
  print('\n── 4. Delete ──');
  await storage.deleteConversation('conv-001');
  print('Deleted conversation conv-001.');

  // Verify deletion
  final deleted = await storage.loadConversation('conv-001');
  print('Exists after delete: ${deleted != null}');

  // ─────────────────────────────────────────
  await storage.dispose();
  print('\n✅ All Storage examples complete.');
}
