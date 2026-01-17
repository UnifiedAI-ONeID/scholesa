import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/offline/offline_queue.dart';

void main() {
  group('QueuedOp', () {
    test('creates with defaults', () {
      final QueuedOp op = QueuedOp(
        type: OpType.attendanceRecord,
        payload: <String, dynamic>{'learnerId': 'learner1'},
      );

      expect(op.id, isNotEmpty);
      expect(op.type, equals(OpType.attendanceRecord));
      expect(op.status, equals(OpStatus.pending));
      expect(op.retryCount, equals(0));
      expect(op.idempotencyKey, isNotEmpty);
    });

    test('converts to Isar model and back', () {
      final QueuedOp op = QueuedOp(
        type: OpType.presenceCheckin,
        payload: <String, dynamic>{'siteId': 'site1', 'learnerId': 'learner1'},
      );

      final model = op.toModel();
      final QueuedOp restored = QueuedOp.fromModel(model);

      expect(restored.type, equals(OpType.presenceCheckin));
      expect(restored.payload['siteId'], equals('site1'));
      expect(restored.status, equals(OpStatus.pending));
    });

    test('preserves all fields through model conversion', () {
      final QueuedOp op = QueuedOp(
        id: 'op123',
        type: OpType.attendanceRecord,
        payload: <String, dynamic>{'learnerId': 'learner1'},
        idempotencyKey: 'key123',
        status: OpStatus.synced,
        retryCount: 2,
        lastError: 'Some error',
      );

      final model = op.toModel();
      final QueuedOp restored = QueuedOp.fromModel(model);

      expect(restored.id, equals('op123'));
      expect(restored.type, equals(OpType.attendanceRecord));
      expect(restored.status, equals(OpStatus.synced));
      expect(restored.retryCount, equals(2));
      expect(restored.lastError, equals('Some error'));
    });
  });

  group('OpType', () {
    test('has all required types from docs/68', () {
      expect(OpType.values, contains(OpType.attendanceRecord));
      expect(OpType.values, contains(OpType.presenceCheckin));
      expect(OpType.values, contains(OpType.presenceCheckout));
      expect(OpType.values, contains(OpType.incidentSubmit));
      expect(OpType.values, contains(OpType.messageSend));
      expect(OpType.values, contains(OpType.attemptSaveDraft));
    });
  });
}
