import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Export service for data export, retention, and compliance
/// Based on docs/43_EXPORT_RETENTION_BACKUP_SPEC.md
/// 
/// Capabilities:
/// - Export site-scoped data (CSV, JSON)
/// - Request exports for roster, attendance, attempts
/// - Track export audit logs
class ExportService extends ChangeNotifier {
  ExportService({
    this.userId,
    this.siteId,
    this.userRole,
    required this.telemetryService,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String? userId;
  final String? siteId;
  final String? userRole;
  final TelemetryService telemetryService;
  final FirebaseFirestore _firestore;

  List<ExportRequest> _exportRequests = <ExportRequest>[];
  bool _isLoading = false;
  String? _error;

  List<ExportRequest> get exportRequests => _exportRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load export requests for user/site
  Future<void> loadExportRequests() async {
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('exportRequests');
      
      // Site admins see site exports, HQ sees all
      if (userRole == 'hq') {
        // HQ can see all exports
      } else if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      } else {
        query = query.where('requestedBy', isEqualTo: userId);
      }

      query = query.orderBy('requestedAt', descending: true).limit(50);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _exportRequests = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return ExportRequest(
          id: doc.id,
          exportType: data['exportType'] as String? ?? 'unknown',
          scope: data['scope'] as String? ?? 'site',
          status: data['status'] as String? ?? 'pending',
          requestedBy: data['requestedBy'] as String? ?? '',
          requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
          downloadUrl: data['downloadUrl'] as String?,
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
          siteId: data['siteId'] as String?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('ExportService.loadExportRequests error: $e');
    }
  }

  /// Request a new data export
  Future<ExportRequest?> requestExport({
    required String exportType, // 'csv_roster', 'csv_attendance', 'json_full', 'artifact_manifest'
    String scope = 'site',
    String? targetSiteId,
  }) async {
    if (userId == null) return null;

    final String targetSite = targetSiteId ?? siteId ?? '';
    
    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('exportRequests').add(<String, dynamic>{
        'exportType': exportType,
        'scope': scope,
        'status': 'pending',
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'siteId': targetSite,
      });

      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'export_requested',
        'actor': userId,
        'target': docRef.id,
        'details': <String, dynamic>{
          'exportType': exportType,
          'scope': scope,
          'siteId': targetSite,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      await telemetryService.trackExportRequested(
        exportType: exportType,
        scope: scope,
        siteId: targetSite,
      );

      final ExportRequest newRequest = ExportRequest(
        id: docRef.id,
        exportType: exportType,
        scope: scope,
        status: 'pending',
        requestedBy: userId!,
        requestedAt: DateTime.now(),
        siteId: targetSite,
      );

      _exportRequests.insert(0, newRequest);
      notifyListeners();

      return newRequest;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('ExportService.requestExport error: $e');
      return null;
    }
  }

  /// Mark export as downloaded (for audit trail)
  Future<void> markDownloaded(String exportId) async {
    if (userId == null) return;

    try {
      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'export_downloaded',
        'actor': userId,
        'target': exportId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      final ExportRequest request = _exportRequests.firstWhere(
        (ExportRequest r) => r.id == exportId,
        orElse: () => ExportRequest(
          id: exportId,
          exportType: 'unknown',
          scope: 'site',
          status: 'completed',
          requestedBy: userId!,
          requestedAt: DateTime.now(),
        ),
      );
      
      await telemetryService.trackExportDownloaded(
        exportId: exportId,
        exportType: request.exportType,
      );
    } catch (e) {
      debugPrint('ExportService.markDownloaded error: $e');
    }
  }

  /// Request data deletion (soft delete first)
  Future<bool> requestDeletion({
    required String targetType, // 'learner', 'site'
    required String targetId,
    String? reason,
  }) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('deletionRequests').add(<String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'status': 'soft_delete_requested',
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'siteId': siteId,
      });

      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'deletion_requested',
        'actor': userId,
        'target': targetId,
        'details': <String, dynamic>{
          'targetType': targetType,
          'reason': reason,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      await telemetryService.trackDeletionRequested(
        targetType: targetType,
        targetId: targetId,
        stage: 'soft_delete',
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('ExportService.requestDeletion error: $e');
      return false;
    }
  }
}

/// Model for export request
class ExportRequest {
  const ExportRequest({
    required this.id,
    required this.exportType,
    required this.scope,
    required this.status,
    required this.requestedBy,
    required this.requestedAt,
    this.completedAt,
    this.downloadUrl,
    this.expiresAt,
    this.siteId,
  });

  final String id;
  final String exportType;
  final String scope;
  final String status;
  final String requestedBy;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? downloadUrl;
  final DateTime? expiresAt;
  final String? siteId;

  bool get isReady => status == 'completed' && downloadUrl != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
