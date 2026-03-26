import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'ai_chat_theme.dart';

/// A message bubble widget for displaying AI chat messages.
class MessageBubble extends StatelessWidget {
  /// The message to display.
  final AIMessage message;

  /// Theme configuration.
  final AIChatTheme theme;

  /// Whether this message is currently being streamed.
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    required this.theme,
    this.isStreaming = false,
  });

  bool get _isUser => message.role == AIRole.user;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Assistant avatar
          if (!_isUser && theme.assistantAvatar != null) ...[
            theme.assistantAvatar!,
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: theme.bubblePadding,
                decoration: BoxDecoration(
                  color: _isUser
                      ? theme.userBubbleColor
                      : theme.assistantBubbleColor,
                  borderRadius: theme.bubbleRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message text
                    SelectableText(
                      message.content,
                      style: _isUser
                          ? theme.userTextStyle
                          : theme.assistantTextStyle,
                    ),

                    // Streaming cursor
                    if (isStreaming)
                      _StreamingCursor(
                        color: theme.assistantTextStyle.color ?? Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // User avatar
          if (_isUser && theme.userAvatar != null) ...[
            const SizedBox(width: 8),
            theme.userAvatar!,
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// A blinking cursor animation for streaming text.
class _StreamingCursor extends StatefulWidget {
  final Color color;
  const _StreamingCursor({required this.color});

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            color: widget.color,
          ),
        );
      },
    );
  }
}
