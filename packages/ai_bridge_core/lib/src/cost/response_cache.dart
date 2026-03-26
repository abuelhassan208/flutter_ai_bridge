import '../models/ai_response.dart';

/// A cached response entry.
class _CacheEntry {
  final AIResponse response;
  final DateTime cachedAt;

  _CacheEntry(this.response) : cachedAt = DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// Caches AI responses to reduce redundant API calls and costs.
///
/// Uses a simple key based on the prompt content. Cached responses
/// expire after a configurable TTL.
class ResponseCache {
  /// Time-to-live for cached entries.
  final Duration ttl;

  /// Maximum number of entries to cache.
  final int maxEntries;

  final Map<String, _CacheEntry> _cache = {};

  ResponseCache({
    this.ttl = const Duration(hours: 1),
    this.maxEntries = 100,
  });

  /// Attempts to retrieve a cached response for the given [key].
  ///
  /// Returns null if not found or expired.
  AIResponse? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired(ttl)) {
      _cache.remove(key);
      return null;
    }

    return entry.response;
  }

  /// Stores a response in the cache with the given [key].
  void put(String key, AIResponse response) {
    // Evict oldest if at capacity
    if (_cache.length >= maxEntries) {
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _cache.remove(oldestKey);
    }

    _cache[key] = _CacheEntry(response);
  }

  /// Generates a cache key from a list of message contents.
  static String keyFromMessages(List<dynamic> messages, String model) {
    final buffer = StringBuffer(model);
    for (final msg in messages) {
      buffer.write('|');
      buffer.write(msg.toString());
    }
    return buffer.toString().hashCode.toString();
  }

  /// Number of entries currently cached.
  int get size => _cache.length;

  /// Clears all cached entries.
  void clear() => _cache.clear();

  /// Removes expired entries.
  void evictExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired(ttl));
  }
}
