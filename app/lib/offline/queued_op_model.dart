import 'dart:convert';

import 'package:isar/isar.dart';

part 'queued_op_model.g.dart';

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

/// Single queued operation stored in Isar
@collection
class QueuedOpModel {
  /// Use nullable Id for auto-increment (avoids large int literal issue on web)
  Id? isarId;

  @Index(unique: true)
  late String opId;

  @Enumerated(EnumType.name)
  late OpType type;

  /// Payload stored as JSON string (Isar doesn't support Map directly)
  late String payloadJson;

  late DateTime createdAt;

  String? idempotencyKey;

  @Enumerated(EnumType.name)
  late OpStatus status;

  late int retryCount;

  String? lastError;

  /// Helper to get payload as Map (ignored by Isar)
  @ignore
  Map<String, dynamic> get payload =>
      jsonDecode(payloadJson) as Map<String, dynamic>;

  /// Helper to set payload from Map
  set payload(Map<String, dynamic> value) => payloadJson = jsonEncode(value);

  /// Create from parameters
  static QueuedOpModel create({
    required String opId,
    required OpType type,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    String? idempotencyKey,
    OpStatus status = OpStatus.pending,
    int retryCount = 0,
    String? lastError,
  }) {
    return QueuedOpModel()
      ..opId = opId
      ..type = type
      ..payloadJson = jsonEncode(payload)
      ..createdAt = createdAt
      ..idempotencyKey = idempotencyKey
      ..status = status
      ..retryCount = retryCount
      ..lastError = lastError;
  }
}
