import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ai_bridge/flutter_ai_bridge.dart';
import 'package:ai_bridge_openai/ai_bridge_openai.dart';
import 'package:ai_bridge_gemini/ai_bridge_gemini.dart';
import 'package:ai_bridge_ollama/ai_bridge_ollama.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    });
  }

  Future<void> _runPipeline() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final openaiKey = prefs.getString('openai_key') ?? '';
      final geminiKey = prefs.getString('gemini_key') ?? '';

      if (openaiKey.isEmpty && geminiKey.isEmpty) {
        _addLog('❌ Error: Please configure API keys first.');
        setState(() => _isRunning = false);
        return;
      }

      // Initialize Providers
      final planningProvider = geminiKey.isNotEmpty
          ? GeminiProvider(config: AIConfig(apiKey: geminiKey, model: 'gemini-2.0-flash'))
          : OllamaProvider(config: AIConfig(apiKey: '', model: 'llama3.2'));
          
      final writerProvider = openaiKey.isNotEmpty
          ? OpenAIProvider(config: AIConfig(apiKey: openaiKey, model: 'gpt-4o-mini'))
          : OllamaProvider(config: AIConfig(apiKey: '', model: 'llama3.2'));

      _addLog('🛠️ Initializing Agents...');
      
      final plannerAgent = ConversationalAgent(
        name: 'TravelPlanner',
        systemPrompt: 'You are an expert travel planner. Given a destination, provide a bulleted list of essential activities. Do not write intros or paragraphs. Just the list.',
        provider: planningProvider,
        outputParser: (res, ctx) {
          ctx.write('itinerary', res);
          _addLog('✅ TravelPlanner completed draft.');
        },
      );

      final marketingAgent = ConversationalAgent(
        name: 'MarketingWriter',
        systemPrompt: 'You write exciting travel blog posts. Read the itinerary provided in the prompt and turn it into an engaging, 2-paragraph social media post with emojis.',
        provider: writerProvider,
        outputParser: (res, ctx) {
          ctx.write('final_copy', res);
          _addLog('✅ MarketingWriter formatted copy.');
        },
      );

      final pipeline = AIPipeline(sequence: [
        AgentTask(
            description: 'Draft an itinerary for: ${_controller.text}',
            assignee: plannerAgent),
        AgentTask(
            description: 'Write a blog post from the itinerary in context.',
            assignee: marketingAgent),
      ]);

      _addLog('🚀 Pipeline Execution Started');
      final stopwatch = Stopwatch()..start();
      
      final context = await pipeline.execute();
      
      stopwatch.stop();
      _addLog('🎉 Pipeline Finished in ${stopwatch.elapsedMilliseconds}ms');
      
      _addLog('\n=== FINAL COPY ===\n${context.read<String>('final_copy') ?? 'No output.'}\n==================\n');

    } catch (e) {
      _addLog('❌ Error: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Orchestration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'This demo uses a multi-agent AIPipeline. The TravelPlanner agent drafts an itinerary '
              '(using Gemini), then passes the context to the MarketingWriter agent (using OpenAI) '
              'to format it into social media copy.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Destination (e.g., Tokyo, Japan)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runPipeline(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _runPipeline,
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_isRunning ? 'Running Pipeline...' : 'Start Agents'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
