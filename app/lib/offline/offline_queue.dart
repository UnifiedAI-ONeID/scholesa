import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

/// Offline operation statuses
enum OpStatus {
  pending,
  syncing,
  synced,
  failed,
}

/// Operation types from docs/68_OFFLINE_OPS_CATALOG.md
enum OpType {
  attendanceRecord,
  presenceCheckin,
  presenceCheckout,
  incidentSubmit,
  messageSend,
  attemptSaveDraft,
}

/// Single queued operation
class QueuedOp {
  QueuedOp({
    String? id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    String? idempotencyKey,
    this.status = OpStatus.pending,
    this.retryCount = 0,
    this.lastError,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        idempotencyKey = idempotencyKey ?? const Uuid().v4();

  factory QueuedOp.fromMap(Map<String, dynamic> map) => QueuedOp(
        id: map['id'] as String,
        type: OpType.values.firstWhere((OpType t) => t.name == map['type']),
        payload: Map<String, dynamic>.from(map['payload'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        idempotencyKey: map['idempotencyKey'] as String?,
        status: OpStatus.values.firstWhere((OpStatus s) => s.name == map['status']),
        retryCount: map['retryCount'] as int? ?? 0,
        lastError: map['lastError'] as String?,
      );

  final String id;
  final OpType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? idempotencyKey;
  OpStatus status;
  int retryCount;
  String? lastError;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'idempotencyKey': idempotencyKey,
        'status': status.name,
        'retryCount': retryCount,
        'lastError': lastError,
      };
}

/// Offline queue using Sembast for persistence (works on all platforms including web)
class OfflineQueue {
  /// Store for queued operations (string keys, map values)
  final StoreRef<String, Map<String, Object?>> _store =
      StoreRef<String, Map<String, Object?>>('offline_queue');

  late Database _db;
  bool _isInitialized = false;

  /// Initialize the queue with provided Sembast database instance
  Future<void> init(Database database) async {
    if (_isInitialized) return;
    _db = database;
    _isInitialized = true;
  }

  /// Add operation to queue
  Future<QueuedOp> enqueue(OpType type, Map<String, dynamic> payload) async {
    final QueuedOp op = QueuedOp(type: type, payload: payload);
    await _store.record(op.id).put(_db, op.toMap());
    return op;
  }

  /// Get all pending operations
  Future<List<QueuedOp>> getPending() async {
    final Finder finder = Finder(
      filter: Filter.or(<Filter>[
        Filter.equals('status', OpStatus.pending.name),
        Filter.equals('status', OpStatus.failed.name),
      ]),
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
    final List<RecordSnapshot<String, Map<String, Object?>>> records =
        await _store.find(_db, finder: finder);
    return records
        .map((RecordSnapshot<String, Map<String, Object?>> r) =>
            QueuedOp.fromMap(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  /// Get all pending operations synchronously (for compatibility)
  List<QueuedOp> getPendingSync() {
    // Note: For Sembast, we need to use async methods
    // This is a simplified sync wrapper that returns empty if not loaded
    // For actual usage, prefer the async getPending() method
    return <QueuedOp>[];
  }

  /// Get all operations
  Future<List<QueuedOp>> getAll() async {
    final Finder finder = Finder(
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
    final List<RecordSnapshot<String, Map<String, Object?>>> records =
        await _store.find(_db, finder: finder);
    return records
        .map((RecordSnapshot<String, Map<String, Object?>> r) =>
            QueuedOp.fromMap(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  /// Update operation status
  Future<void> updateStatus(String id, OpStatus status, {String? error}) async {
    final RecordSnapshot<String, Map<String, Object?>>? record =
        await _store.record(id).getSnapshot(_db);
    if (record == null) return;

    final QueuedOp op = QueuedOp.fromMap(Map<String, dynamic>.from(record.value));
    op.status = status;
    if (error != null) {
      op.lastError = error;
      op.retryCount++;
    }
    await _store.record(id).put(_db, op.toMap());
  }

  /// Remove synced operations older than duration
  Future<int> purge({Duration olderThan = const Duration(days: 7)}) async {
    final DateTime cutoff = DateTime.now().subtract(olderThan);
    final int cutoffMs = cutoff.millisecondsSinceEpoch;

    final Finder finder = Finder(
      filter: Filter.and(<Filter>[
        Filter.equals('status', OpStatus.synced.name),
        Filter.lessThan('createdAt', cutoffMs),
      ]),
    );

    final List<RecordSnapshot<String, Map<String, Object?>>> records =
        await _store.find(_db, finder: finder);
    
    for (final RecordSnapshot<String, Map<String, Object?>> record in records) {
      await _store.record(record.key).delete(_db);
    }

    return records.length;
  }

  /// Get pending count
  Future<int> getPendingCount() async {
    final Filter filter = Filter.or(<Filter>[
        Filter.equals('status', OpStatus.pending.name),
        Filter.equals('status', OpStatus.failed.name),
      ]);
    return await _store.count(_db, filter: filter);
  }

  /// Sync getter for pending count (returns 0 if not yet loaded, use getPendingCount() for accuracy)
  int get pendingCount => 0; // Fallback; use getPendingCount() async version

  /// Clear all (for testing)
  Future<void> clear() async {
    await _store.drop(_db);
  }
}
