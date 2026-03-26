import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ai_bridge/flutter_ai_bridge.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';
import 'package:ai_bridge_claude/ai_bridge_claude.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';
import 'package:ai_bridge_storage_shared_prefs/ai_bridge_storage_shared_prefs.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AIBridge? _bridge;
  ConversationManager? _conversationManager;
  StorageProvider? _storageProvider;

  List<Conversation> _history = [];
  Conversation? _activeConversation;

  bool _isLoading = true;
  String _activeProvider = 'None';

  @override
  void initState() {
    super.initState();
    _initializeBridge();
  }

  Future<void> _initializeBridge() async {
    final prefs = await SharedPreferences.getInstance();
    final openaiKey = prefs.getString('openai_key') ?? '';
    final geminiKey = prefs.getString('gemini_key') ?? '';
    final claudeKey = prefs.getString('claude_key') ?? '';

    final providers = <AIProvider>[];

    if (geminiKey.isNotEmpty) {
      providers.add(
        GeminiProvider(
          config: AIConfig(apiKey: geminiKey, model: 'gemini-2.0-flash'),
        ),
      );
    }
    if (openaiKey.isNotEmpty) {
      providers.add(
        OpenAIProvider(
          config: AIConfig(apiKey: openaiKey, model: 'gpt-4o-mini'),
        ),
      );
    }
    if (claudeKey.isNotEmpty) {
      providers.add(
        ClaudeProvider(
          config: AIConfig(apiKey: claudeKey, model: 'claude-3-haiku-20240307'),
        ),
      );
    }

    // Always add Ollama for local Edge fallback (no key needed)
    providers.add(
      OllamaProvider(
        config: AIConfig(apiKey: 'local', model: 'llama3.2'),
      ),
    );

    if (providers.isNotEmpty) {
      _bridge = AIBridge(
        providers: providers,
        strategy: RoutingStrategy.costOptimized,
        budget: TokenBudget(maxTokensPerDay: 50000),
      );

      _storageProvider = await SharedPreferencesStorageProvider.create();
      _conversationManager = ConversationManager(
        provider: _BridgeProxyProvider(_bridge!),
        storage: _storageProvider,
      );

      // Load history
      _history = await _conversationManager!.loadAll();

      // Create a new conversation if history is empty, otherwise use the most recent
      if (_history.isEmpty) {
        _activeConversation = _conversationManager!.create(
          systemPrompt:
              'You are a helpful assistant powered by Flutter AI Bridge.',
          title: 'New Conversation',
        );
        _history.add(_activeConversation!);
      } else {
        _activeConversation = _history.first;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _startNewConversation() {
    if (_conversationManager == null) return;
    setState(() {
      _activeConversation = _conversationManager!.create(
        systemPrompt:
            'You are a helpful assistant powered by Flutter AI Bridge.',
        title: 'New Conversation',
      );
      _history.insert(0, _activeConversation!);
    });
    Navigator.pop(context); // Close drawer
  }

  void _loadConversation(Conversation conv) {
    setState(() {
      _activeConversation = conv;
    });
    Navigator.pop(context); // Close drawer
  }

  void _deleteConversation(Conversation conv) {
    setState(() {
      _conversationManager?.delete(conv.id);
      _history.removeWhere((c) => c.id == conv.id);
      if (_activeConversation?.id == conv.id) {
        if (_history.isNotEmpty) {
          _activeConversation = _history.first;
        } else {
          _activeConversation = _conversationManager?.create();
          if (_activeConversation != null) _history.add(_activeConversation!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bridge == null || _conversationManager == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Bridge Chat')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No API keys found.\n\nPlease go to the Config tab '
              'and add at least one provider key.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Bridge Chat'),
            Text(
              'Served by: $_activeProvider',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Chats'),
              accountEmail: Text('${_history.length} Conversations'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.forum),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Chat'),
              onTap: _startNewConversation,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final conv = _history[index];
                  final isSelected = conv.id == _activeConversation?.id;

                  return ListTile(
                    selected: isSelected,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      conv.title ?? 'Chat ${conv.id.substring(5, 12)}...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${conv.messageCount} messages'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteConversation(conv),
                    ),
                    onTap: () => _loadConversation(conv),
                  );
                },
              ),
            )
          ],
        ),
      ),
      body: AIChatWidget(
        // Key changes to force widget rebuild when conversation changes
        key: ValueKey(_activeConversation?.id),
        provider: _BridgeProxyProvider(_bridge!),
        conversationManager: _conversationManager,
        activeConversation: _activeConversation,
        tools: [
          AITool(
            name: 'get_weather',
            description: 'Get the current weather for a specified location.',
            parameters: {
              'type': 'object',
              'properties': {
                'location': {
                  'type': 'string',
                  'description': 'The city and state, e.g. San Francisco, CA'
                }
              },
              'required': ['location']
            },
            execute: (args) async {
              final loc = args['location'] ?? 'Unknown location';
              await Future.delayed(
                  const Duration(seconds: 1)); // Simulate network
              return 'The weather in $loc is currently 72°F and sunny.';
            },
          ),
        ],
        theme: AIChatTheme.dark(),
        onResponse: (response) {
          setState(() {
            _activeProvider = response.provider;
            // Update title if it's new
            if (_activeConversation != null &&
                _activeConversation!.messageCount == 2) {
              _activeConversation!.title =
                  '${_activeConversation!.messages[1].content.split(' ').take(4).join(' ')}...';
              _storageProvider?.saveConversation(_activeConversation!);
            }
          });
        },
      ),
    );
  }
}

/// Proxy provider
class _BridgeProxyProvider implements AIProvider {
  final AIBridge bridge;

  _BridgeProxyProvider(this.bridge);

  @override
  String get name => 'AIBridge Router';

  @override
  String get model => 'Auto';

  @override
  AIConfig get config => bridge.primaryProvider.config;

  @override
  List<AICapability> get capabilities => bridge.primaryProvider.capabilities;

  @override
  bool supports(AICapability capability) =>
      bridge.primaryProvider.supports(capability);

  @override
  Future<AIResponse> complete(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) {
    return bridge.completeMessages(
      messages,
      maxTokens: maxTokens,
      temperature: temperature,
      tools: tools,
    );
  }

  @override
  Stream<AIStreamChunk> completeStream(
    List<AIMessage> messages, {
    int? maxTokens,
    double? temperature,
    List<AITool>? tools,
  }) {
    return bridge.router.routeStream(
      messages,
      maxTokens: maxTokens,
      temperature: temperature,
      tools: tools,
    );
  }

  @override
  int estimateTokens(String text) =>
      bridge.primaryProvider.estimateTokens(text);

  @override
  Future<List<double>> embed(String text) => bridge.primaryProvider.embed(text);

  @override
  Future<void> dispose() => bridge.dispose();
}
