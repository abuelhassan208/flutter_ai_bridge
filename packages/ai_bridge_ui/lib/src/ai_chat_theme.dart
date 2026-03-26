import 'package:flutter/material.dart';

/// Theme configuration for AI chat widgets.
class AIChatTheme {
  /// Background color of the chat area.
  final Color backgroundColor;

  /// Color for user message bubbles.
  final Color userBubbleColor;

  /// Color for assistant message bubbles.
  final Color assistantBubbleColor;

  /// Text style for user messages.
  final TextStyle userTextStyle;

  /// Text style for assistant messages.
  final TextStyle assistantTextStyle;

  /// Border radius for message bubbles.
  final BorderRadius bubbleRadius;

  /// Padding inside message bubbles.
  final EdgeInsets bubblePadding;

  /// Spacing between messages.
  final double messageSpacing;

  /// Icon/avatar for the assistant.
  final Widget? assistantAvatar;

  /// Icon/avatar for the user.
  final Widget? userAvatar;

  /// Input bar decoration.
  final InputDecoration? inputDecoration;

  /// Send button icon.
  final IconData sendIcon;

  /// Send button color.
  final Color sendButtonColor;

  const AIChatTheme({
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.userBubbleColor = const Color(0xFF1976D2),
    this.assistantBubbleColor = const Color(0xFFFFFFFF),
    this.userTextStyle = const TextStyle(color: Colors.white, fontSize: 15),
    this.assistantTextStyle =
        const TextStyle(color: Colors.black87, fontSize: 15),
    this.bubbleRadius = const BorderRadius.all(Radius.circular(16)),
    this.bubblePadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.messageSpacing = 8,
    this.assistantAvatar,
    this.userAvatar,
    this.inputDecoration,
    this.sendIcon = Icons.send_rounded,
    this.sendButtonColor = const Color(0xFF1976D2),
  });

  /// A modern dark theme for AI chat.
  factory AIChatTheme.dark() {
    return const AIChatTheme(
      backgroundColor: Color(0xFF1A1A2E),
      userBubbleColor: Color(0xFF0F3460),
      assistantBubbleColor: Color(0xFF16213E),
      userTextStyle: TextStyle(color: Colors.white, fontSize: 15),
      assistantTextStyle: TextStyle(color: Color(0xFFE0E0E0), fontSize: 15),
      sendButtonColor: Color(0xFF533483),
    );
  }

  /// A clean light theme for AI chat.
  factory AIChatTheme.light() {
    return const AIChatTheme();
  }

  /// A gradient-accent theme.
  factory AIChatTheme.gradient() {
    return const AIChatTheme(
      backgroundColor: Color(0xFFF0F2F5),
      userBubbleColor: Color(0xFF6C63FF),
      assistantBubbleColor: Color(0xFFFFFFFF),
      sendButtonColor: Color(0xFF6C63FF),
    );
  }
}
