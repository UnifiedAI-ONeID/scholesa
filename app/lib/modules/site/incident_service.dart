import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/telemetry_service.dart';

/// Service for incident management - safety, consent, and incident workflows
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class IncidentService extends ChangeNotifier {
  IncidentService({
    this.siteId,
    this.userId,
    this.userRole,
    this.telemetryService,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String? siteId;
  final String? userId;
  final String? userRole;
  final TelemetryService? telemetryService;

  // State
  List<Incident> _incidents = <Incident>[];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Incident> get incidents => _incidents;
  List<Incident> get openIncidents => _incidents.where((Incident i) => i.status == IncidentStatus.submitted).toList();
  List<Incident> get reviewedIncidents => _incidents.where((Incident i) => i.status == IncidentStatus.reviewed).toList();
  List<Incident> get closedIncidents => _incidents.where((Incident i) => i.status == IncidentStatus.closed).toList();
  List<Incident> get criticalIncidents => _incidents.where((Incident i) => i.severity == IncidentSeverity.critical).toList();
  List<Incident> get majorIncidents => _incidents.where((Incident i) => i.severity == IncidentSeverity.major).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load incidents for the site (or all sites for HQ)
  Future<void> loadIncidents() async {
    // HQ can see all sites
    if (userRole != 'hq' && siteId == null) {
      _error = 'Site not set';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('incidents')
          .orderBy('reportedAt', descending: true);

      // Site admins only see their site
      if (userRole != 'hq' && siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.limit(100).get();

      _incidents = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Incident.fromMap(doc.id, data);
      }).toList();

      debugPrint('Loaded ${_incidents.length} incidents');
    } catch (e) {
      _error = 'Failed to load incidents: $e';
      debugPrint(_error);
      _incidents = <Incident>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load only escalated/critical incidents (for HQ oversight)
  Future<void> loadEscalatedIncidents() async {
    if (userRole != 'hq') return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('incidents')
          .where('severity', whereIn: <String>['major', 'critical'])
          .orderBy('reportedAt', descending: true)
          .limit(50)
          .get();

      _incidents = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Incident.fromMap(doc.id, data);
      }).toList();

      debugPrint('Loaded ${_incidents.length} escalated incidents');
    } catch (e) {
      _error = 'Failed to load escalated incidents: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new incident report
  Future<bool> createIncident({
    required String title,
    required String description,
    required IncidentSeverity severity,
    required String category,
    required String learnerId,
    required String learnerName,
  }) async {
    if (siteId == null || userId == null) return false;

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('incidents').add(<String, dynamic>{
        'siteId': siteId,
        'title': title,
        'description': description,
        'severity': severity.name,
        'category': category,
        'status': IncidentStatus.submitted.name,
        'learnerId': learnerId,
        'learnerName': learnerName,
        'reportedBy': userId,
        'reportedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      telemetryService?.trackIncidentCreated(
        incidentId: docRef.id,
        severity: severity.name,
        category: category,
      );

      await loadIncidents();
      return true;
    } catch (e) {
      _error = 'Failed to create incident: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update incident status
  Future<bool> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus newStatus,
    String? notes,
  }) async {
    try {
      final Incident? incident = _incidents.where((Incident i) => i.id == incidentId).firstOrNull;
      final String fromStatus = incident?.status.name ?? 'unknown';

      await _firestore.collection('incidents').doc(incidentId).update(<String, dynamic>{
        'status': newStatus.name,
        'statusNotes': notes,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': userId,
      });

      // Track telemetry
      telemetryService?.trackIncidentStatusChanged(
        incidentId: incidentId,
        fromStatus: fromStatus,
        toStatus: newStatus.name,
      );

      await loadIncidents();
      return true;
    } catch (e) {
      _error = 'Failed to update incident status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add a note/update to an incident
  Future<bool> addIncidentNote({
    required String incidentId,
    required String note,
  }) async {
    if (userId == null) return false;

    try {
      await _firestore
          .collection('incidents')
          .doc(incidentId)
          .collection('notes')
          .add(<String, dynamic>{
        'note': note,
        'addedBy': userId,
        'addedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _error = 'Failed to add note: $e';
      notifyListeners();
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

enum IncidentSeverity { minor, major, critical }
enum IncidentStatus { submitted, reviewed, closed }

class Incident {

  factory Incident.fromMap(String id, Map<String, dynamic> data) {
    return Incident(
      id: id,
      siteId: data['siteId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      severity: IncidentSeverity.values.firstWhere(
        (IncidentSeverity s) => s.name == data['severity'],
        orElse: () => IncidentSeverity.minor,
      ),
      category: data['category'] as String? ?? 'other',
      status: IncidentStatus.values.firstWhere(
        (IncidentStatus s) => s.name == data['status'],
        orElse: () => IncidentStatus.submitted,
      ),
      learnerId: data['learnerId'] as String? ?? '',
      learnerName: data['learnerName'] as String? ?? 'Unknown',
      reportedBy: data['reportedBy'] as String? ?? '',
      reportedAt: _parseTimestamp(data['reportedAt']) ?? DateTime.now(),
      statusNotes: data['statusNotes'] as String?,
      statusUpdatedAt: _parseTimestamp(data['statusUpdatedAt']),
      statusUpdatedBy: data['statusUpdatedBy'] as String?,
    );
  }
  const Incident({
    required this.id,
    required this.siteId,
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    required this.status,
    required this.learnerId,
    required this.learnerName,
    required this.reportedBy,
    required this.reportedAt,
    this.statusNotes,
    this.statusUpdatedAt,
    this.statusUpdatedBy,
  });

  final String id;
  final String siteId;
  final String title;
  final String description;
  final IncidentSeverity severity;
  final String category;
  final IncidentStatus status;
  final String learnerId;
  final String learnerName;
  final String reportedBy;
  final DateTime reportedAt;
  final String? statusNotes;
  final DateTime? statusUpdatedAt;
  final String? statusUpdatedBy;

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
