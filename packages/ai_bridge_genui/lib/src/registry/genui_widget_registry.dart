import 'package:flutter/widgets.dart';

/// A function that builds a Flutter Widget from a JSON data map.
typedef GenUIWidgetBuilder = Widget Function(
    BuildContext context, Map<String, dynamic> data);

/// Represents a Flutter widget that the AI can generate dynamically.
class RegisteredGenUIWidget {
  /// The unique name of the widget (e.g., 'weather_card').
  /// The AI will use this name to call the widget.
  final String name;

  /// A description of what this widget does.
  /// Used by the AI to determine when to render it.
  final String description;

  /// The JSON Schema describing the properties this widget needs.
  /// Example: {'type': 'object', 'properties': {'temp': {'type': 'number'}}}
  final Map<String, dynamic> parametersSchema;

  /// The function that turns the AI's JSON into a native Flutter widget.
  final GenUIWidgetBuilder builder;

  const RegisteredGenUIWidget({
    required this.name,
    required this.description,
    required this.parametersSchema,
    required this.builder,
  });
}

/// A central registry holding all UI components the AI is allowed to generate.
class GenUIWidgetRegistry {
  final Map<String, RegisteredGenUIWidget> _widgets = {};

  /// Registers a new widget that the AI can generate.
  void register(RegisteredGenUIWidget widget) {
    _widgets[widget.name] = widget;
  }

  /// Retrieves a registered widget by its exact name.
  RegisteredGenUIWidget? getWidget(String name) {
    return _widgets[name];
  }

  /// Returns a list of all currently registered widgets.
  List<RegisteredGenUIWidget> get allWidgets => _widgets.values.toList();

  /// Clears the registry.
  void clear() {
    _widgets.clear();
  }
}
