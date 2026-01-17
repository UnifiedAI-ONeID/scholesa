import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import 'queued_op_model.dart';

export 'queued_op_model.dart' show OpStatus, OpType;

/// Legacy QueuedOp class for API compatibility
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

  factory QueuedOp.fromModel(QueuedOpModel model) => QueuedOp(
        id: model.opId,
        type: model.type,
        payload: model.payload,
        createdAt: model.createdAt,
        idempotencyKey: model.idempotencyKey,
        status: model.status,
        retryCount: model.retryCount,
        lastError: model.lastError,
      );

  final String id;
  final OpType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? idempotencyKey;
  OpStatus status;
  int retryCount;
  String? lastError;

  QueuedOpModel toModel() => QueuedOpModel.create(
        opId: id,
        type: type,
        payload: payload,
        createdAt: createdAt,
        idempotencyKey: idempotencyKey,
        status: status,
        retryCount: retryCount,
        lastError: lastError,
      );
}

/// Offline queue using Isar for persistence
class OfflineQueue {
  late Isar _isar;
  bool _isInitialized = false;

  /// Initialize the queue with provided Isar instance
  Future<void> init(Isar isar) async {
    if (_isInitialized) return;
    _isar = isar;
    _isInitialized = true;
  }

  /// Add operation to queue
  Future<QueuedOp> enqueue(OpType type, Map<String, dynamic> payload) async {
    final QueuedOp op = QueuedOp(type: type, payload: payload);
    await _isar.writeTxn(() async {
      await _isar.queuedOpModels.put(op.toModel());
    });
    return op;
  }

  /// Get all pending operations
  List<QueuedOp> getPending() {
    final List<QueuedOpModel> models = _isar.queuedOpModels
        .filter()
        .statusEqualTo(OpStatus.pending)
        .or()
        .statusEqualTo(OpStatus.failed)
        .sortByCreatedAt()
        .findAllSync();
    return models.map(QueuedOp.fromModel).toList();
  }

  /// Get all operations
  List<QueuedOp> getAll() {
    final List<QueuedOpModel> models =
        _isar.queuedOpModels.where().sortByCreatedAt().findAllSync();
    return models.map(QueuedOp.fromModel).toList();
  }

  /// Update operation status
  Future<void> updateStatus(String id, OpStatus status, {String? error}) async {
    await _isar.writeTxn(() async {
      final QueuedOpModel? model =
          await _isar.queuedOpModels.filter().opIdEqualTo(id).findFirst();
      if (model == null) return;

      model.status = status;
      if (error != null) {
        model.lastError = error;
        model.retryCount++;
      }
      await _isar.queuedOpModels.put(model);
    });
  }

  /// Remove synced operations older than duration
  Future<int> purge({Duration olderThan = const Duration(days: 7)}) async {
    final DateTime cutoff = DateTime.now().subtract(olderThan);
    int count = 0;

    await _isar.writeTxn(() async {
      count = await _isar.queuedOpModels
          .filter()
          .statusEqualTo(OpStatus.synced)
          .createdAtLessThan(cutoff)
          .deleteAll();
    });

    return count;
  }

  /// Get pending count
  int get pendingCount {
    return _isar.queuedOpModels
        .filter()
        .statusEqualTo(OpStatus.pending)
        .or()
        .statusEqualTo(OpStatus.failed)
        .countSync();
  }

  /// Clear all (for testing)
  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.queuedOpModels.clear();
    });
  }
}
