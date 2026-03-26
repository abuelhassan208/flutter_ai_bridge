import 'ai_error.dart';

/// States the circuit breaker can be in.
enum CircuitState {
  /// Normal operation — requests pass through.
  closed,

  /// Too many failures — requests are blocked.
  open,

  /// Testing if the service has recovered — one request allowed.
  halfOpen,
}

/// Circuit breaker pattern to prevent cascading failures.
///
/// When a provider fails repeatedly, the circuit breaker opens and
/// blocks further requests for a cooldown period. After the cooldown,
/// it allows one test request (half-open) to check if the service recovered.
class CircuitBreaker {
  /// Name of this circuit (typically the provider name).
  final String name;

  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// How long to keep the circuit open before testing again.
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 60),
  });

  /// Current state of the circuit.
  CircuitState get state {
    if (_state == CircuitState.open && _shouldReset()) {
      _state = CircuitState.halfOpen;
    }
    return _state;
  }

  /// Whether requests are currently allowed through.
  bool get isAllowed => state != CircuitState.open;

  /// Records a successful request.
  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  /// Records a failed request.
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// Executes [action] through the circuit breaker.
  ///
  /// Throws [AINetworkError] if the circuit is open.
  Future<T> execute<T>(Future<T> Function() action) async {
    if (!isAllowed) {
      throw AINetworkError(
        provider: name,
        message:
            'Circuit breaker is open — provider "$name" is temporarily unavailable. '
            'Will retry after ${resetTimeout.inSeconds}s.',
      );
    }

    try {
      final result = await action();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      rethrow;
    }
  }

  /// Resets the circuit breaker to closed state.
  void reset() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastFailureTime = null;
  }

  bool _shouldReset() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) >= resetTimeout;
  }
}
