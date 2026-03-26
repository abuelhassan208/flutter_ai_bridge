import 'package:flutter/material.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_genui/ai_bridge_genui.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';

class GenUIScreen extends StatefulWidget {
  const GenUIScreen({super.key});

  @override
  State<GenUIScreen> createState() => _GenUIScreenState();
}

class _GenUIScreenState extends State<GenUIScreen> {
  late final GenUIWidgetRegistry _registry;
  ConversationalAgent? _agent;
  late final AgentContext _context;
  
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupRegistry();
    _setupAgent();
  }

  void _setupRegistry() {
    _registry = GenUIWidgetRegistry();
    
    // 1. Register a dynamic Weather Card
    _registry.register(RegisteredGenUIWidget(
      name: 'weather_card',
      description: 'Displays a beautiful daily weather forecast for a specific city.',
      parametersSchema: {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
          'temperature_celsius': {'type': 'number'},
          'condition': {'type': 'string', 'enum': ['Sunny', 'Rainy', 'Cloudy', 'Snow']},
        },
        'required': ['city', 'temperature_celsius', 'condition'],
      },
      builder: (context, data) {
        final condition = data['condition'] as String;
        final icon = condition == 'Sunny' ? Icons.wb_sunny : condition == 'Rainy' ? Icons.water_drop : Icons.cloud;
        final color = condition == 'Sunny' ? Colors.orange : Colors.blueGrey;
        
        return Card(
          elevation: 4,
          color: color.shade100,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['city'] as String, style: Theme.of(context).textTheme.titleLarge),
                    Text('${data['temperature_celsius']}°C - $condition'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ));
    
    // 2. Register an Interactive Flight Ticket
    _registry.register(RegisteredGenUIWidget(
      name: 'flight_ticket',
      description: 'Displays a flight boarding pass ticket.',
      parametersSchema: {
        'type': 'object',
        'properties': {
          'airline': {'type': 'string'},
          'from': {'type': 'string', 'description': 'Airport code'},
          'to': {'type': 'string', 'description': 'Airport code'},
          'price': {'type': 'number'},
        },
        'required': ['airline', 'from', 'to', 'price'],
      },
      builder: (context, data) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.flight_takeoff, color: Colors.blue),
            title: Text('${data['from']} ➔ ${data['to']}'),
            subtitle: Text(data['airline'] as String),
            trailing: Text('\$${data['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        );
      },
    ));
  }

  Future<void> _setupAgent() async {
    _context = AgentContext();
    
    final prefs = await SharedPreferences.getInstance();
    final openaiKey = prefs.getString('openai_key') ?? '';
    final geminiKey = prefs.getString('gemini_key') ?? '';
    
    // Default to Gemini since it handles tools extremely well, but fallback
    final provider = geminiKey.isNotEmpty 
        ? GeminiProvider(config: AIConfig(apiKey: geminiKey, model: 'gemini-2.0-flash'))
        : (openaiKey.isNotEmpty 
            ? OpenAIProvider(config: AIConfig(apiKey: openaiKey, model: 'gpt-4o-mini'))
            : OllamaProvider(config: AIConfig(apiKey: '', model: 'llama3.2')));
            
    setState(() {
      _agent = ConversationalAgent(
        name: 'GenUIAssistant',
        systemPrompt: 'You are an advanced UI assistant. When the user asks for weather or flights, ALWAYS use the provided render_ui_widget tool instead of describing it in text. Keep text responses short and mostly rely on the UI.',
        provider: provider,
        tools: [GenUITool(registry: _registry)],
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    if (text.isEmpty || _agent == null) return;

    _controller.clear();
    setState(() {
      _context.conversation.addMessage(AIMessage.user(text));
    });

    await _agent!.execute(_context, taskInput: text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_agent == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final messages = _context.conversation.messages;
    // ... rest of the build method
    return Scaffold(
      appBar: AppBar(title: const Text('Generative UI Demo')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                
                // If it's a user message
                if (msg.role == AIRole.user) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8, left: 40),
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(16)),
                      child: Text(msg.content, style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }
                
                // If it has GenUI Tool Calls, render the Widget natively
                if (msg.toolCalls?.isNotEmpty == true) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: msg.toolCalls!.map((call) {
                      if (call.name == 'render_ui_widget') {
                        final args = call.arguments;
                        return AIGeneratedView(
                          registry: _registry,
                          widgetName: args['widget_name'] as String? ?? '',
                          data: args['widget_data'] as Map<String, dynamic>? ?? {},
                          onUnknownWidget: (ctx, name) => Text('Error: AI tried to render unknown widget: $name', style: const TextStyle(color: Colors.red)),
                          onError: (ctx, e) => Text('UI Rendering Error: $e', style: const TextStyle(color: Colors.red)),
                        );
                      }
                      return Text('Unknown Tool Called: ${call.name}');
                    }).toList(),
                  );
                }
                
                // Otherwise it's normal assistant text
                if (msg.role == AIRole.assistant && msg.content.isNotEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8, right: 40),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                      child: Text(msg.content),
                    ),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. "What is the weather like in Tokyo?"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

