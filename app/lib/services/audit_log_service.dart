import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Audit Log service for compliance and export tracking
/// Based on docs/43_EXPORT_RETENTION_BACKUP_SPEC.md
/// 
/// Features:
/// - View audit logs for compliance
/// - Request data exports
/// - Track deletion requests
class AuditLogService extends ChangeNotifier {
  AuditLogService({
    required this.telemetryService,
    this.userId,
    this.siteId,
    this.userRole,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? siteId;
  final String? userRole;
  final FirebaseFirestore _firestore;

  List<AuditLogEntry> _logs = <AuditLogEntry>[];
  List<ExportRequest> _exports = <ExportRequest>[];
  List<DeletionRequest> _deletions = <DeletionRequest>[];
  bool _isLoading = false;
  String? _error;

  List<AuditLogEntry> get logs => _logs;
  List<ExportRequest> get exports => _exports;
  List<DeletionRequest> get deletions => _deletions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIT LOGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load audit logs (site-scoped for site admin, all for HQ)
  Future<void> loadAuditLogs({int limit = 100}) async {
    if (userRole != 'site' && userRole != 'hq') {
      _error = 'Unauthorized: Admin role required';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // Site admins only see their site's logs
      if (userRole == 'site' && siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _logs = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return AuditLogEntry(
          id: doc.id,
          action: data['action'] as String? ?? '',
          targetId: data['targetId'] as String?,
          targetType: data['targetType'] as String?,
          userId: data['userId'] as String?,
          siteId: data['siteId'] as String?,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          metadata: data['metadata'] as Map<String, dynamic>?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('AuditLogService.loadAuditLogs error: $e');
    }
  }

  /// Filter logs by action type
  List<AuditLogEntry> filterByAction(String action) =>
      _logs.where((AuditLogEntry l) => l.action.contains(action)).toList();

  /// Filter logs by date range
  List<AuditLogEntry> filterByDateRange(DateTime start, DateTime end) =>
      _logs.where((AuditLogEntry l) => 
          l.timestamp.isAfter(start) && l.timestamp.isBefore(end)).toList();

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load export requests
  Future<void> loadExportRequests() async {
    if (userRole != 'site' && userRole != 'hq') return;

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('exportRequests')
          .orderBy('requestedAt', descending: true)
          .limit(50);

      if (userRole == 'site' && siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _exports = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return ExportRequest(
          id: doc.id,
          exportType: data['exportType'] as String? ?? '',
          scope: data['scope'] as String? ?? '',
          status: _parseExportStatus(data['status'] as String?),
          requestedBy: data['requestedBy'] as String?,
          requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
          downloadUrl: data['downloadUrl'] as String?,
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('AuditLogService.loadExportRequests error: $e');
    }
  }

  /// Request a new export
  Future<ExportRequest?> requestExport({
    required String exportType, // 'csv_roster', 'json_full', 'artifact_manifest'
    required String scope, // 'site', 'organization'
  }) async {
    if (userRole != 'site' && userRole != 'hq') {
      _error = 'Unauthorized: Admin role required';
      notifyListeners();
      return null;
    }

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('exportRequests').add(<String, dynamic>{
        'exportType': exportType,
        'scope': scope,
        'siteId': scope == 'site' ? siteId : null,
        'status': ExportStatus.pending.name,
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Write audit log
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'export.requested',
        'targetId': docRef.id,
        'targetType': 'export',
        'userId': userId,
        'siteId': siteId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': <String, dynamic>{
          'exportType': exportType,
          'scope': scope,
        },
      });

      await telemetryService.trackExportRequested(
        exportType: exportType,
        scope: scope,
        siteId: siteId,
      );

      final ExportRequest request = ExportRequest(
        id: docRef.id,
        exportType: exportType,
        scope: scope,
        status: ExportStatus.pending,
        requestedBy: userId,
        requestedAt: DateTime.now(),
      );

      _exports.insert(0, request);
      notifyListeners();

      return request;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AuditLogService.requestExport error: $e');
      return null;
    }
  }

  /// Download an export (marks it downloaded in audit)
  Future<void> trackExportDownload(String exportId) async {
    try {
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'export.downloaded',
        'targetId': exportId,
        'targetType': 'export',
        'userId': userId,
        'siteId': siteId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final ExportRequest? export = _exports.where((ExportRequest e) => e.id == exportId).firstOrNull;
      if (export != null) {
        await telemetryService.trackExportDownloaded(
          exportId: exportId,
          exportType: export.exportType,
        );
      }
    } catch (e) {
      debugPrint('AuditLogService.trackExportDownload error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETION REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load deletion requests
  Future<void> loadDeletionRequests() async {
    if (userRole != 'hq') return; // Only HQ can view deletion requests

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('deletionRequests')
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      _deletions = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return DeletionRequest(
          id: doc.id,
          targetType: data['targetType'] as String? ?? '',
          targetId: data['targetId'] as String? ?? '',
          stage: _parseDeletionStage(data['stage'] as String?),
          requestedBy: data['requestedBy'] as String?,
          requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          scheduledHardDeleteAt: (data['scheduledHardDeleteAt'] as Timestamp?)?.toDate(),
          legalHold: data['legalHold'] as bool? ?? false,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('AuditLogService.loadDeletionRequests error: $e');
    }
  }

  /// Request deletion of a resource
  Future<DeletionRequest?> requestDeletion({
    required String targetType, // 'learner', 'site'
    required String targetId,
  }) async {
    if (userRole != 'hq') {
      _error = 'Unauthorized: HQ role required';
      notifyListeners();
      return null;
    }

    try {
      // Calculate scheduled hard delete (30 days from now)
      final DateTime scheduledHardDelete = DateTime.now().add(const Duration(days: 30));

      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('deletionRequests').add(<String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'stage': DeletionStage.softDelete.name,
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'scheduledHardDeleteAt': Timestamp.fromDate(scheduledHardDelete),
        'legalHold': false,
      });

      // Write audit log
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'deletion.requested',
        'targetId': targetId,
        'targetType': targetType,
        'userId': userId,
        'siteId': siteId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': <String, dynamic>{
          'stage': DeletionStage.softDelete.name,
          'scheduledHardDeleteAt': scheduledHardDelete.toIso8601String(),
        },
      });

      await telemetryService.trackDeletionRequested(
        targetType: targetType,
        targetId: targetId,
        stage: DeletionStage.softDelete.name,
      );

      final DeletionRequest request = DeletionRequest(
        id: docRef.id,
        targetType: targetType,
        targetId: targetId,
        stage: DeletionStage.softDelete,
        requestedBy: userId,
        requestedAt: DateTime.now(),
        scheduledHardDeleteAt: scheduledHardDelete,
        legalHold: false,
      );

      _deletions.insert(0, request);
      notifyListeners();

      return request;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AuditLogService.requestDeletion error: $e');
      return null;
    }
  }

  /// Set legal hold on a deletion request
  Future<bool> setLegalHold(String deletionId, bool hold) async {
    if (userRole != 'hq') return false;

    try {
      await _firestore.collection('deletionRequests').doc(deletionId).update(<String, dynamic>{
        'legalHold': hold,
        if (hold) 'scheduledHardDeleteAt': FieldValue.delete(),
      });

      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': hold ? 'deletion.legal_hold_set' : 'deletion.legal_hold_removed',
        'targetId': deletionId,
        'targetType': 'deletion_request',
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await loadDeletionRequests();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AuditLogService.setLegalHold error: $e');
      return false;
    }
  }

  ExportStatus _parseExportStatus(String? status) {
    return ExportStatus.values.firstWhere(
      (ExportStatus s) => s.name == status,
      orElse: () => ExportStatus.pending,
    );
  }

  DeletionStage _parseDeletionStage(String? stage) {
    return DeletionStage.values.firstWhere(
      (DeletionStage s) => s.name == stage,
      orElse: () => DeletionStage.softDelete,
    );
  }
}

/// Model for audit log entry
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    this.targetId,
    this.targetType,
    this.userId,
    this.siteId,
    required this.timestamp,
    this.metadata,
  });

  final String id;
  final String action;
  final String? targetId;
  final String? targetType;
  final String? userId;
  final String? siteId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}

/// Status of an export request
enum ExportStatus {
  pending,
  processing,
  completed,
  failed,
  expired,
}

/// Model for export request
class ExportRequest {
  const ExportRequest({
    required this.id,
    required this.exportType,
    required this.scope,
    required this.status,
    this.requestedBy,
    required this.requestedAt,
    this.completedAt,
    this.downloadUrl,
    this.expiresAt,
  });

  final String id;
  final String exportType;
  final String scope;
  final ExportStatus status;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? downloadUrl;
  final DateTime? expiresAt;

  bool get isReady => status == ExportStatus.completed && downloadUrl != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Stage of a deletion request
enum DeletionStage {
  softDelete,
  hardDeleteScheduled,
  hardDeleteCompleted,
}

/// Model for deletion request
class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.stage,
    this.requestedBy,
    required this.requestedAt,
    this.scheduledHardDeleteAt,
    required this.legalHold,
  });

  final String id;
  final String targetType;
  final String targetId;
  final DeletionStage stage;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? scheduledHardDeleteAt;
  final bool legalHold;

  bool get canHardDelete => !legalHold && 
      scheduledHardDeleteAt != null && 
      DateTime.now().isAfter(scheduledHardDeleteAt!);
}
