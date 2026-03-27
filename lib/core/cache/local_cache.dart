// lib/core/cache/local_cache.dart

import 'package:hive_flutter/hive_flutter.dart';

class CacheEntry {
  final dynamic data;
  final int timestampMs;
  final int ttlMs;

  const CacheEntry({
    required this.data,
    required this.timestampMs,
    required this.ttlMs,
  });

  bool get isExpired {
    if (ttlMs <= 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestampMs) > ttlMs;
  }
}

class LocalCache {
  static const _boxName = 'talky_cache';
  static final LocalCache instance = LocalCache._internal();

  LocalCache._internal();

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box _box() => Hive.box(_boxName);

  CacheEntry? getEntry(String key) {
    final raw = _box().get(key);
    if (raw is! Map) return null;
    final data = raw['data'];
    final ts = raw['ts'] as int? ?? 0;
    final ttl = raw['ttl'] as int? ?? 0;
    return CacheEntry(data: data, timestampMs: ts, ttlMs: ttl);
  }

  T? get<T>(String key, {T Function(dynamic)? mapper}) {
    final entry = getEntry(key);
    if (entry == null || entry.isExpired) return null;
    if (mapper != null) return mapper(entry.data);
    return entry.data as T?;
  }

  T? getAllowExpired<T>(String key, {T Function(dynamic)? mapper}) {
    final entry = getEntry(key);
    if (entry == null) return null;
    if (mapper != null) return mapper(entry.data);
    return entry.data as T?;
  }

  Future<void> set(
    String key,
    dynamic data, {
    Duration? ttl,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = ttl?.inMilliseconds ?? 0;
    await _box().put(key, {
      'data': data,
      'ts': ts,
      'ttl': ttlMs,
    });
  }

  Future<void> remove(String key) async {
    await _box().delete(key);
  }

  Future<void> clearPrefix(String prefix) async {
    final keys = _box().keys
        .where((k) => k is String && k.startsWith(prefix))
        .toList();
    await _box().deleteAll(keys);
  }
}
