import 'dart:async';
import 'package:flutter/material.dart';

/// A widget that animates text appearing character by character,
/// simulating a typewriter/streaming effect.
///
/// ```dart
/// StreamingText(
///   text: 'Hello, this text will appear gradually...',
///   style: TextStyle(fontSize: 16),
///   speed: Duration(milliseconds: 20),
/// )
/// ```
class StreamingText extends StatefulWidget {
  /// The full text to display.
  final String text;

  /// Text style.
  final TextStyle? style;

  /// Speed per character.
  final Duration speed;

  /// Whether to animate or show instantly.
  final bool animate;

  /// Callback when animation completes.
  final VoidCallback? onComplete;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 20),
    this.animate = true,
    this.onComplete,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  int _charCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _startAnimation();
    } else {
      _charCount = widget.text.length;
    }
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      // New text is longer — continue from where we are
      if (widget.text.length > _charCount) {
        _startAnimation();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_charCount >= widget.text.length) {
        timer.cancel();
        widget.onComplete?.call();
        return;
      }
      setState(() {
        _charCount++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.substring(
      0,
      _charCount.clamp(0, widget.text.length),
    );

    return Text(
      displayText,
      style: widget.style,
    );
  }
}
