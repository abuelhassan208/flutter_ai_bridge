import 'package:flutter/material.dart';
import 'package:ai_bridge_core/ai_bridge_core.dart';
import 'ai_chat_theme.dart';
import 'message_bubble.dart';
import 'input_bar.dart';

/// A complete AI chat widget with message list, streaming support,
/// and input bar.
///
/// ```dart
/// AIChatWidget(
///   provider: myOpenAIProvider,
///   systemPrompt: 'You are a helpful assistant.',
///   theme: AIChatTheme.dark(),
/// )
/// ```
class AIChatWidget extends StatefulWidget {
  /// The AI provider to use for completions.
  final AIProvider provider;

  /// Optional system prompt.
  final String? systemPrompt;

  /// Theme for the chat UI.
  final AIChatTheme theme;

  /// Placeholder text for the input field.
  final String hintText;

  /// Custom builder for message bubbles.
  final Widget Function(AIMessage message, bool isStreaming)? messageBuilder;

  /// Callback when a response is received.
  final void Function(AIResponse response)? onResponse;

  /// Callback on error.
  final void Function(AIError error)? onError;

  /// Maximum context tokens for conversation.
  final int maxContextTokens;

  /// Optional pre-configured manager (allows injecting storage).
  final ConversationManager? conversationManager;

  /// Optional active conversation to load.
  final Conversation? activeConversation;

  /// Optional list of tools the AI can use autonomously.
  final List<AITool>? tools;

  const AIChatWidget({
    super.key,
    required this.provider,
    this.systemPrompt,
    this.theme = const AIChatTheme(),
    this.hintText = 'Type a message...',
    this.messageBuilder,
    this.onResponse,
    this.onError,
    this.maxContextTokens = 4096,
    this.conversationManager,
    this.activeConversation,
    this.tools,
  });

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> {
  late final ConversationManager _conversationManager;
  late final Conversation _conversation;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    _conversationManager = widget.conversationManager ??
        ConversationManager(
          provider: widget.provider,
          maxContextTokens: widget.maxContextTokens,
        );

    if (widget.activeConversation != null) {
      _conversation = widget.activeConversation!;
    } else {
      _conversation = _conversationManager.create(
        systemPrompt: widget.systemPrompt,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _streamingText = '';
    });
    _scrollToBottom();

    try {
      // Use streaming for better UX, unless tools are provided
      // (streaming tool execution is not yet supported by ConversationManager)
      if (widget.provider.supports(AICapability.streaming) &&
          widget.tools == null) {
        final buffer = StringBuffer();
        await for (final chunk in _conversationManager.sendStream(
          _conversation.id,
          text,
        )) {
          buffer.write(chunk.text);
          setState(() {
            _streamingText = buffer.toString();
          });
          _scrollToBottom();
        }
      } else {
        final response = await _conversationManager.send(
          _conversation.id,
          text,
          tools: widget.tools,
        );
        widget.onResponse?.call(response);
      }
    } on AIError catch (e) {
      widget.onError?.call(e);
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _streamingText = '';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayMessages =
        _conversation.messages.where((m) => m.role != AIRole.system).toList();

    return Container(
      color: widget.theme.backgroundColor,
      child: Column(
        children: [
          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: displayMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // Streaming message
                if (_isLoading && index == displayMessages.length) {
                  if (_streamingText.isEmpty) {
                    return _buildTypingIndicator();
                  }
                  final streamMsg = AIMessage.assistant(_streamingText);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: widget.theme.messageSpacing,
                    ),
                    child: widget.messageBuilder?.call(streamMsg, true) ??
                        MessageBubble(
                          message: streamMsg,
                          theme: widget.theme,
                          isStreaming: true,
                        ),
                  );
                }

                final message = displayMessages[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.theme.messageSpacing,
                  ),
                  child: widget.messageBuilder?.call(message, false) ??
                      MessageBubble(
                        message: message,
                        theme: widget.theme,
                      ),
                );
              },
            ),
          ),

          // Input bar
          AIInputBar(
            theme: widget.theme,
            hintText: widget.hintText,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 64),
        padding: widget.theme.bubblePadding,
        decoration: BoxDecoration(
          color: widget.theme.assistantBubbleColor,
          borderRadius: widget.theme.bubbleRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 600 + i * 200),
              builder: (context, value, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: 0.3 + 0.7 * value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.theme.assistantTextStyle.color ??
                            Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
