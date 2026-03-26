// ignore_for_file: avoid_print
/// Comprehensive usage examples for `ai_bridge_genui`.
///
/// Demonstrates the Server-Driven Generative UI system:
/// - Registering custom Flutter widgets
/// - Creating a GenUITool for the LLM
/// - Wiring it with a ConversationalAgent
/// - Rendering AI-generated widgets with AIGeneratedView
///
/// Note: This example requires a Flutter environment.
/// For a full runnable demo, see `flutter_ai_bridge/example/`.
library;

import 'package:flutter/material.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'package:ai_bridge_genui/ai_bridge_genui.dart';

// ─────────────────────────────────────────────
// 1. Define Custom Widgets
// ─────────────────────────────────────────────

/// A weather card rendered dynamically by the LLM.
class WeatherCard extends StatelessWidget {
  final String city;
  final int temperature;
  final String condition;

  const WeatherCard({
    super.key,
    required this.city,
    required this.temperature,
    required this.condition,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(city,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('$temperature°C — $condition',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. Register Widgets in the Registry
// ─────────────────────────────────────────────

GenUIWidgetRegistry createRegistry() {
  final registry = GenUIWidgetRegistry();

  registry.register(RegisteredGenUIWidget(
    name: 'weather_card',
    description: 'Displays current weather for a city',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'City name'},
        'temperature': {'type': 'integer', 'description': 'Temperature in °C'},
        'condition': {
          'type': 'string',
          'description': 'Weather condition (Sunny, Rainy, etc.)'
        },
      },
      'required': ['city', 'temperature', 'condition'],
    },
    builder: (context, data) => WeatherCard(
      city: data['city'] as String,
      temperature: data['temperature'] as int,
      condition: data['condition'] as String,
    ),
  ));

  return registry;
}

// ─────────────────────────────────────────────
// 3. Create the GenUI Tool
// ─────────────────────────────────────────────

/// The GenUITool auto-generates a JSON Schema union of all registered widgets.
/// When given to the LLM as a tool, the model can "call" any widget by name
/// with validated parameters.
AITool createGenUITool() {
  final registry = createRegistry();
  return GenUITool(registry: registry);
}

// ─────────────────────────────────────────────
// 4. Wire with ConversationalAgent
// ─────────────────────────────────────────────

/// In a real app, you would wire the tool into a ConversationalAgent:
///
/// ```dart
/// final agent = ConversationalAgent(
///   name: 'UIAgent',
///   systemPrompt: 'You render UI widgets. Always use the render_ui tool.',
///   provider: geminiProvider,
///   tools: [createGenUITool()],
/// );
/// ```

// ─────────────────────────────────────────────
// 5. Render with AIGeneratedView
// ─────────────────────────────────────────────

/// Place AIGeneratedView in your widget tree to auto-render
/// any widget the LLM generates:
///
/// ```dart
/// AIGeneratedView(
///   toolCall: lastToolCallFromAgent,
///   registry: registry,
///   fallback: Text('No widget rendered yet.'),
/// )
/// ```

// ─────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────
void main() {
  final registry = createRegistry();
  final tool = GenUITool(registry: registry);

  print('═══════════════════════════════════════════════');
  print('  ai_bridge_genui — Server-Driven UI Example');
  print('═══════════════════════════════════════════════');
  print('');
  print(
      'Registered widgets: ${registry.allWidgets.map((w) => w.name).toList()}');
  print('Tool name: ${tool.name}');
  print('Tool description: ${tool.description}');
  print('');
  print('The LLM can now call "${tool.name}" with parameters like:');
  print(
      '  {"widget": "weather_card", "city": "Cairo", "temperature": 35, "condition": "Sunny"}');
  print('');
  print('AIGeneratedView will automatically render the native Flutter widget.');
  print('');
  print('For a full interactive demo, run: flutter_ai_bridge/example/');
}
