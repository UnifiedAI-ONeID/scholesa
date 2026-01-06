import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

part 'offline_queue.g.dart';

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

@collection
class PendingActionEntity {
  PendingActionEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String actionId;

  late String type;
  late String payloadJson;
  late DateTime createdAt;

  PendingAction toPendingAction() {
    final Map<String, dynamic> payloadMap = jsonDecode(payloadJson) as Map<String, dynamic>;
    return PendingAction(
      id: actionId,
      type: type,
      payload: payloadMap,
      createdAt: createdAt,
    );
  }

  static PendingActionEntity fromPendingAction(PendingAction action) {
    return PendingActionEntity()
      ..actionId = action.id
      ..type = action.type
      ..payloadJson = jsonEncode(action.payload)
      ..createdAt = action.createdAt;
  }
}

/// OfflineQueue persists pending actions and flushes when online.
class OfflineQueue extends ChangeNotifier {
  OfflineQueue();

  final List<PendingAction> _pending = <PendingAction>[];
  final Map<String, Future<bool> Function(PendingAction)> _dispatchers = {};
  bool _initialized = false;
  bool _isFlushing = false;
  DateTime? _lastSyncedAt;

  Isar? _isar;
  Future<void>? _loadFuture;

  List<PendingAction> get pending => List.unmodifiable(_pending);
  bool get hasPending => _pending.isNotEmpty;
  bool get initialized => _initialized;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isFlushing => _isFlushing;

  Future<void> load() async {
    _loadFuture ??= _init();
    await _loadFuture;
  }

  Future<void> _init() async {
    final isar = await _openIsar();
    final stored = await isar.pendingActionEntitys.where().sortByCreatedAt().findAll();
    _pending
      ..clear()
      ..addAll(stored.map((e) => e.toPendingAction()));
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
    await load();
    _pending.removeWhere((p) => p.id == action.id);
    _pending.add(action);
    await _persistAction(action);
    notifyListeners();
  }

  Future<void> flush({required bool online}) async {
    if (!online || _isFlushing) return;
    await load();
    if (_pending.isEmpty) return;
    _isFlushing = true;
    try {
      final List<PendingAction> remaining = <PendingAction>[];
      for (final action in List<PendingAction>.from(_pending)) {
        final dispatcher = _dispatchers[action.type];
        if (dispatcher == null) {
          remaining.add(action);
          continue;
        }
        try {
          final sent = await dispatcher(action);
          if (!sent) {
            remaining.add(action);
          }
        } catch (_) {
          remaining.add(action);
        }
      }
      _pending
        ..clear()
        ..addAll(remaining);
      await _persistAll();
      if (remaining.isEmpty) {
        _lastSyncedAt = DateTime.now();
      }
    } finally {
      _isFlushing = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await load();
    _pending.clear();
    final isar = await _openIsar();
    await isar.writeTxn(() async {
      await isar.pendingActionEntitys.clear();
    });
    notifyListeners();
  }

  Future<void> _persistAction(PendingAction action) async {
    final isar = await _openIsar();
    final entity = PendingActionEntity.fromPendingAction(action);
    await isar.writeTxn(() async {
      await isar.pendingActionEntitys.put(entity);
    });
  }

  Future<void> _persistAll() async {
    final isar = await _openIsar();
    await isar.writeTxn(() async {
      await isar.pendingActionEntitys.clear();
      await isar.pendingActionEntitys.putAll(_pending.map(PendingActionEntity.fromPendingAction).toList());
    });
  }

  Future<Isar> _openIsar() async {
    if (_isar != null) return _isar!;
    // Cache open future to avoid duplicate opens.
    if (kIsWeb) {
      _isar = await Isar.open(
        [PendingActionEntitySchema],
        name: 'offline_queue',
        directory: 'isar_web',
        inspector: false,
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [PendingActionEntitySchema],
        name: 'offline_queue',
        directory: dir.path,
        inspector: false,
      );
    }
    return _isar!;
  }
}
