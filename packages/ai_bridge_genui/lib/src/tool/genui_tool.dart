import 'package:ai_bridge_core/ai_bridge_core.dart';
import '../registry/genui_widget_registry.dart';

/// Converts a [GenUIWidgetRegistry] into a standard [AITool] that
/// the LLM can "call" to render UI.
class GenUITool extends AITool {
  GenUITool({required GenUIWidgetRegistry registry})
      : super(
          name: 'render_ui_widget',
          description:
              'Use this tool when you want to render a rich, interactive UI widget for the user instead of displaying plain text. You MUST choose a `widget_name` strictly from the registered widgets, and strictly follow its required `widget_data` schema.',
          parameters: _buildSchema(registry),
          execute: (arguments) async {
            final widgetName = arguments['widget_name'] as String?;
            if (widgetName == null) {
              return 'Error: widget_name is missing.';
            }

            final widget = registry.getWidget(widgetName);
            if (widget == null) {
              return 'Error: Widget "$widgetName" does not exist in the registry.';
            }

            // Since this is a UI-rendering tool, from the purely logical perspective
            // of the LLM, the execution simply returns a confirmation that the UI was requested.
            // The actual Flutter frontend intercepts `AIToolCall` objects with this name
            // and passes their arguments to `AIGeneratedView`.
            return 'Success. The user is now seeing the $widgetName widget. Do not describe the widget to them, they can see it.';
          },
        );

  static Map<String, dynamic> _buildSchema(GenUIWidgetRegistry registry) {
    // Generate a massive union schema defining the exact shapes
    // of every registered widget in the registry.
    final enumNames = registry.allWidgets.map((w) => w.name).toList();

    return {
      'type': 'object',
      'properties': {
        'widget_name': {
          'type': 'string',
          'description': 'The exact ID of the widget you want to render.',
          'enum': enumNames.isEmpty ? ['none_registered'] : enumNames,
        },
        'widget_data': {
          'type': 'object',
          'description':
              'The raw unstructured JSON arguments required by the widget. You must ensure you fulfill the props correctly based on the widget type.',
        }
      },
      'required': ['widget_name', 'widget_data'],
    };
  }
}
