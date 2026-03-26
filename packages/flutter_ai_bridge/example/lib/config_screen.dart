import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _openAiController = TextEditingController();
  final _geminiController = TextEditingController();
  final _claudeController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _openAiController.text = prefs.getString('openai_key') ?? '';
      _geminiController.text = prefs.getString('gemini_key') ?? '';
      _claudeController.text = prefs.getString('claude_key') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_key', _openAiController.text.trim());
    await prefs.setString('gemini_key', _geminiController.text.trim());
    await prefs.setString('claude_key', _claudeController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Keys saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Providers Configuration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Enter your API keys to test the providers locally. '
                  'These are saved only on your device using SharedPreferences.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildKeyField(
                  label: 'OpenAI API Key',
                  controller: _openAiController,
                  icon: Icons.api,
                ),
                const SizedBox(height: 16),
                _buildKeyField(
                  label: 'Gemini API Key',
                  controller: _geminiController,
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(height: 16),
                _buildKeyField(
                  label: 'Claude API Key',
                  controller: _claudeController,
                  icon: Icons.psychology,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _saveKeys,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Keys'),
                ),
              ],
            ),
    );
  }

  Widget _buildKeyField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        helperText: 'Starts with sk-... or AI...',
      ),
    );
  }
}
