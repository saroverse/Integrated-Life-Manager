import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Notifies the UI whenever the pending-ops count changes.
final pendingOpsNotifier = ValueNotifier<int>(0);

// ─── Pending Operation ────────────────────────────────────────────────────────

class PendingOp {
  final String id;
  final String method; // POST | PUT | DELETE
  final String path;
  final dynamic body;
  final DateTime createdAt;

  const PendingOp({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: j['id'] as String,
        method: j['method'] as String,
        path: j['path'] as String,
        body: j['body'],
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ─── Local Cache ──────────────────────────────────────────────────────────────

class LocalCache {
  static SharedPreferences? _prefs;
  static const _cachePrefix = 'ilm_cache:';
  static const _queueKey = 'ilm_pending_ops';
  static const _uuid = Uuid();

  /// Call once at app startup (before runApp).
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _refreshNotifier();
  }

  // ── Response Cache ─────────────────────────────────────────────────────────

  /// Persist a successful API response so it can be returned offline.
  static Future<void> saveResponse(String key, dynamic data) async {
    try {
      await _prefs?.setString('$_cachePrefix$key', jsonEncode(data));
    } catch (_) {}
  }

  /// Return the last cached response for [key], or null if nothing cached.
  static dynamic getResponse(String key) {
    final s = _prefs?.getString('$_cachePrefix$key');
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  // ── Pending Queue ──────────────────────────────────────────────────────────

  static List<PendingOp> get pendingOps {
    final s = _prefs?.getString(_queueKey);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => PendingOp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int get pendingCount => pendingOps.length;

  /// Add a mutation to the pending queue. Returns its generated ID.
  static Future<String> enqueue(String method, String path,
      {dynamic body}) async {
    final ops = pendingOps;
    final id = _uuid.v4();
    ops.add(PendingOp(
        id: id, method: method, path: path, body: body, createdAt: DateTime.now()));
    await _prefs?.setString(
        _queueKey, jsonEncode(ops.map((o) => o.toJson()).toList()));
    _refreshNotifier();
    return id;
  }

  /// Remove a successfully replayed op from the queue.
  static Future<void> dequeue(String id) async {
    final ops = pendingOps..removeWhere((o) => o.id == id);
    await _prefs?.setString(
        _queueKey, jsonEncode(ops.map((o) => o.toJson()).toList()));
    _refreshNotifier();
  }

  static Future<void> clearQueue() async {
    await _prefs?.remove(_queueKey);
    _refreshNotifier();
  }

  static void _refreshNotifier() {
    pendingOpsNotifier.value = pendingCount;
  }
}
