import 'dart:async';

/// A token that allows cancellation of in-flight AI requests.
///
/// Pass this to `ConversationManager.send()` or `AIBridge.complete()`
/// to enable cancellation from the UI or timeout logic.
///
/// ```dart
/// final token = CancellationToken();
/// // Later...
/// token.cancel(); // cancels the in-flight request
/// ```
class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  /// Whether cancellation has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Cancel the associated operation.
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Throws [CancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (isCancelled) {
      throw CancelledException();
    }
  }
}

/// Exception thrown when an operation is cancelled via [CancellationToken].
class CancelledException implements Exception {
  final String message;
  CancelledException([this.message = 'Operation was cancelled.']);

  @override
  String toString() => 'CancelledException: $message';
}
