import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingAction {
  PendingAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// OfflineQueue persists pending actions and flushes when online.
class OfflineQueue extends ChangeNotifier {
  static const _storageKey = 'offline_queue_v1';

  OfflineQueue();

  final List<PendingAction> _pending = <PendingAction>[];
  final Map<String, Future<bool> Function(PendingAction)> _dispatchers = {};
  bool _initialized = false;
  bool _isFlushing = false;

  List<PendingAction> get pending => List.unmodifiable(_pending);
  bool get hasPending => _pending.isNotEmpty;
  bool get initialized => _initialized;

  Future<void> load() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey) ?? <String>[];
    _pending
      ..clear()
      ..addAll(stored
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .map(PendingAction.fromJson));
    _initialized = true;
    notifyListeners();
  }

  void registerDispatcher(
    String type,
    Future<bool> Function(PendingAction action) dispatcher,
  ) {
    _dispatchers[type] = dispatcher;
  }

  Future<void> enqueue(PendingAction action) async {
    _pending.removeWhere((p) => p.id == action.id);
    _pending.add(action);
    await _persist();
    notifyListeners();
  }

  Future<void> flush({required bool online}) async {
    if (!online || _isFlushing || _pending.isEmpty) return;
    _isFlushing = true;
    try {
      final List<PendingAction> remaining = <PendingAction>[];
      for (final action in List<PendingAction>.from(_pending)) {
        final dispatcher = _dispatchers[action.type];
        if (dispatcher == null) {
          remaining.add(action);
          continue;
        }
        final sent = await dispatcher(action);
        if (!sent) {
          remaining.add(action);
        }
      }
      _pending
        ..clear()
        ..addAll(remaining);
      await _persist();
    } finally {
      _isFlushing = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _pending.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _pending.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }
}
