import 'package:flutter/material.dart';
import 'ai_chat_theme.dart';

/// Input bar for the AI chat widget.
class AIInputBar extends StatefulWidget {
  /// Theme configuration.
  final AIChatTheme theme;

  /// Placeholder text.
  final String hintText;

  /// Whether a message is being processed.
  final bool isLoading;

  /// Callback when the user sends a message.
  final void Function(String text) onSend;

  const AIInputBar({
    super.key,
    required this.theme,
    required this.hintText,
    required this.isLoading,
    required this.onSend,
  });

  @override
  State<AIInputBar> createState() => _AIInputBarState();
}

class _AIInputBarState extends State<AIInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.theme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.theme.assistantBubbleColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.isLoading,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: widget.theme.inputDecoration ??
                      InputDecoration(
                        hintText: widget.hintText,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                      ),
                  style: TextStyle(
                    fontSize: 15,
                    color: widget.theme.assistantTextStyle.color,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: _hasText && !widget.isLoading
                    ? widget.theme.sendButtonColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _hasText && !widget.isLoading ? _handleSend : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.theme.sendIcon,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
