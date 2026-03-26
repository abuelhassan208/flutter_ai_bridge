import '../errors/ai_error.dart';
import '../models/ai_response.dart';

/// Controls token spending with configurable budgets.
///
/// Prevents runaway API costs by enforcing limits per request,
/// per session, and per day.
class TokenBudget {
  /// Maximum tokens per single request.
  final int? maxTokensPerRequest;

  /// Maximum tokens per session (resets when [resetSession] is called).
  final int? maxTokensPerSession;

  /// Maximum tokens per day.
  final int? maxTokensPerDay;

  int _sessionTokens = 0;
  int _dailyTokens = 0;
  DateTime _dayStart = _startOfDay(DateTime.now());

  TokenBudget({
    this.maxTokensPerRequest,
    this.maxTokensPerSession,
    this.maxTokensPerDay,
  });

  /// Tokens used in the current session.
  int get sessionTokensUsed => _sessionTokens;

  /// Tokens used today.
  int get dailyTokensUsed => _dailyTokens;

  /// Remaining tokens in the session budget (null if unlimited).
  int? get sessionRemaining => maxTokensPerSession != null
      ? maxTokensPerSession! - _sessionTokens
      : null;

  /// Remaining tokens in the daily budget (null if unlimited).
  int? get dailyRemaining =>
      maxTokensPerDay != null ? maxTokensPerDay! - _dailyTokens : null;

  /// Checks whether a request with [estimatedTokens] can proceed.
  ///
  /// Returns true if within all budgets.
  bool canProceed(int estimatedTokens) {
    _checkDayRollover();

    if (maxTokensPerRequest != null && estimatedTokens > maxTokensPerRequest!) {
      return false;
    }
    if (maxTokensPerSession != null &&
        _sessionTokens + estimatedTokens > maxTokensPerSession!) {
      return false;
    }
    if (maxTokensPerDay != null &&
        _dailyTokens + estimatedTokens > maxTokensPerDay!) {
      return false;
    }
    return true;
  }

  /// Enforces the budget — throws [AIBudgetExceededError] if over budget.
  void enforce(int estimatedTokens) {
    if (!canProceed(estimatedTokens)) {
      throw AIBudgetExceededError(
        message: 'Token budget exceeded. '
            'Session: $_sessionTokens/${maxTokensPerSession ?? '∞'}, '
            'Daily: $_dailyTokens/${maxTokensPerDay ?? '∞'}, '
            'Request: $estimatedTokens/${maxTokensPerRequest ?? '∞'}',
      );
    }
  }

  /// Records token usage from a completed response.
  void recordUsage(AIUsage usage) {
    _checkDayRollover();
    _sessionTokens += usage.totalTokens;
    _dailyTokens += usage.totalTokens;
  }

  /// Resets the session budget.
  void resetSession() {
    _sessionTokens = 0;
  }

  /// Resets all budgets.
  void resetAll() {
    _sessionTokens = 0;
    _dailyTokens = 0;
    _dayStart = _startOfDay(DateTime.now());
  }

  void _checkDayRollover() {
    final today = _startOfDay(DateTime.now());
    if (today.isAfter(_dayStart)) {
      _dailyTokens = 0;
      _dayStart = today;
    }
  }

  static DateTime _startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
