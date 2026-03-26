import 'package:flutter/widgets.dart';
import '../registry/genui_widget_registry.dart';

/// A Flutter widget that dynamically renders an AI-generated component
/// by matching a known [widgetName] against the [GenUIWidgetRegistry].
class AIGeneratedView extends StatelessWidget {
  /// The local registry describing what UI can be rendered.
  final GenUIWidgetRegistry registry;

  /// The name of the widget the AI wants to render.
  final String widgetName;

  /// The JSON data the AI provided for the widget.
  final Map<String, dynamic> data;

  /// Optional builder triggered if the AI hallucinates an unregistered widget name.
  final Widget Function(BuildContext context, String requestedName)? onUnknownWidget;

  /// Optional builder triggered if the target Widget fails to build (e.g., missing cast).
  final Widget Function(BuildContext context, Object error)? onError;

  const AIGeneratedView({
    super.key,
    required this.registry,
    required this.widgetName,
    required this.data,
    this.onUnknownWidget,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    final registered = registry.getWidget(widgetName);

    if (registered == null) {
      if (onUnknownWidget != null) {
        return onUnknownWidget!(context, widgetName);
      }
      // Fail silently if no error builder provided for hallucinated widgets.
      return const SizedBox.shrink();
    }

    try {
      return registered.builder(context, data);
    } catch (e) {
      if (onError != null) {
        return onError!(context, e);
      }
      return const SizedBox.shrink();
    }
  }
}
