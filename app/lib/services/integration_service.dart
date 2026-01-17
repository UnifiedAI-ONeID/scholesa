import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Integration service for Google Classroom and GitHub connections
/// Based on docs/36_INTEGRATIONS_INTERNAL_API_CONTRACT.md
/// 
/// Client-side service for:
/// - Managing integration connections
/// - Viewing sync job status
/// - Initiating OAuth flows
/// - Viewing external course/assignment links
class IntegrationService extends ChangeNotifier {
  IntegrationService({
    required this.telemetryService,
    this.userId,
    this.siteId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? siteId;
  final FirebaseFirestore _firestore;

  List<IntegrationConnection> _connections = <IntegrationConnection>[];
  List<SyncJob> _syncJobs = <SyncJob>[];
  List<ExternalCourseLink> _courseLinks = <ExternalCourseLink>[];
  bool _isLoading = false;
  String? _error;

  List<IntegrationConnection> get connections => _connections;
  List<SyncJob> get syncJobs => _syncJobs;
  List<ExternalCourseLink> get courseLinks => _courseLinks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if a provider is connected
  bool isProviderConnected(String provider) =>
      _connections.any((IntegrationConnection c) => 
          c.provider == provider && c.status == ConnectionStatus.active);

  // ═══════════════════════════════════════════════════════════════════════════
  // CONNECTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load integration connections for user
  Future<void> loadConnections() async {
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('integrationConnections')
          .where('userId', isEqualTo: userId)
          .orderBy('connectedAt', descending: true)
          .get();

      _connections = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return IntegrationConnection(
          id: doc.id,
          provider: data['provider'] as String? ?? '',
          status: _parseConnectionStatus(data['status'] as String?),
          externalAccountId: data['externalAccountId'] as String?,
          externalAccountName: data['externalAccountName'] as String?,
          scopes: List<String>.from(data['scopes'] as List<dynamic>? ?? <dynamic>[]),
          connectedAt: (data['connectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastSyncAt: (data['lastSyncAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('IntegrationService.loadConnections error: $e');
    }
  }

  /// Disconnect an integration
  Future<bool> disconnectProvider(String connectionId) async {
    try {
      await _firestore.collection('integrationConnections').doc(connectionId).update(<String, dynamic>{
        'status': ConnectionStatus.disconnected.name,
        'disconnectedAt': FieldValue.serverTimestamp(),
      });

      final int index = _connections.indexWhere((IntegrationConnection c) => c.id == connectionId);
      if (index >= 0) {
        _connections[index] = IntegrationConnection(
          id: _connections[index].id,
          provider: _connections[index].provider,
          status: ConnectionStatus.disconnected,
          externalAccountId: _connections[index].externalAccountId,
          externalAccountName: _connections[index].externalAccountName,
          scopes: _connections[index].scopes,
          connectedAt: _connections[index].connectedAt,
          lastSyncAt: _connections[index].lastSyncAt,
        );
        notifyListeners();
      }

      await telemetryService.logEvent('integration.disconnected', metadata: <String, dynamic>{
        'provider': _connections[index].provider,
      });

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('IntegrationService.disconnectProvider error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC JOBS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load sync jobs for site
  Future<void> loadSyncJobs() async {
    if (siteId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('syncJobs')
          .where('siteId', isEqualTo: siteId)
          .orderBy('startedAt', descending: true)
          .limit(50)
          .get();

      _syncJobs = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return SyncJob(
          id: doc.id,
          provider: data['provider'] as String? ?? '',
          jobType: data['jobType'] as String? ?? '',
          status: _parseSyncStatus(data['status'] as String?),
          startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
          itemsProcessed: data['itemsProcessed'] as int? ?? 0,
          itemsFailed: data['itemsFailed'] as int? ?? 0,
          errorMessage: data['errorMessage'] as String?,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('IntegrationService.loadSyncJobs error: $e');
    }
  }

  /// Request a roster sync (triggers Cloud Function)
  Future<bool> requestRosterSync({
    required String courseId,
    required String sessionId,
  }) async {
    if (siteId == null) return false;

    try {
      // Create a sync job request - Cloud Function will process
      await _firestore.collection('syncJobs').add(<String, dynamic>{
        'provider': 'google_classroom',
        'jobType': 'roster_sync',
        'status': SyncJobStatus.pending.name,
        'siteId': siteId,
        'courseId': courseId,
        'sessionId': sessionId,
        'requestedBy': userId,
        'startedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.logEvent('integration.roster_sync.requested', metadata: <String, dynamic>{
        'provider': 'google_classroom',
        'courseId': courseId,
      });

      await loadSyncJobs();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('IntegrationService.requestRosterSync error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COURSE LINKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load external course links for site
  Future<void> loadCourseLinks() async {
    if (siteId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('externalCourseLinks')
          .where('siteId', isEqualTo: siteId)
          .orderBy('linkedAt', descending: true)
          .get();

      _courseLinks = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return ExternalCourseLink(
          id: doc.id,
          provider: data['provider'] as String? ?? '',
          externalCourseId: data['externalCourseId'] as String? ?? '',
          externalCourseName: data['externalCourseName'] as String?,
          sessionId: data['sessionId'] as String?,
          linkedAt: (data['linkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('IntegrationService.loadCourseLinks error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GITHUB
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load GitHub connections (if any)
  Future<List<GitHubConnection>> loadGitHubConnections() async {
    if (userId == null) return <GitHubConnection>[];

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('githubConnections')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return GitHubConnection(
          id: doc.id,
          username: data['username'] as String? ?? '',
          installationId: data['installationId'] as String?,
          connectedAt: (data['connectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('IntegrationService.loadGitHubConnections error: $e');
      return <GitHubConnection>[];
    }
  }

  ConnectionStatus _parseConnectionStatus(String? status) {
    return ConnectionStatus.values.firstWhere(
      (ConnectionStatus s) => s.name == status,
      orElse: () => ConnectionStatus.disconnected,
    );
  }

  SyncJobStatus _parseSyncStatus(String? status) {
    return SyncJobStatus.values.firstWhere(
      (SyncJobStatus s) => s.name == status,
      orElse: () => SyncJobStatus.pending,
    );
  }
}

/// Status of an integration connection
enum ConnectionStatus {
  active,
  disconnected,
  expired,
  error,
}

/// Status of a sync job
enum SyncJobStatus {
  pending,
  running,
  completed,
  failed,
}

/// Model for integration connection
class IntegrationConnection {
  const IntegrationConnection({
    required this.id,
    required this.provider,
    required this.status,
    this.externalAccountId,
    this.externalAccountName,
    required this.scopes,
    required this.connectedAt,
    this.lastSyncAt,
  });

  final String id;
  final String provider; // 'google_classroom', 'github'
  final ConnectionStatus status;
  final String? externalAccountId;
  final String? externalAccountName;
  final List<String> scopes;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;

  bool get isActive => status == ConnectionStatus.active;
}

/// Model for sync job
class SyncJob {
  const SyncJob({
    required this.id,
    required this.provider,
    required this.jobType,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.itemsProcessed,
    required this.itemsFailed,
    this.errorMessage,
  });

  final String id;
  final String provider;
  final String jobType;
  final SyncJobStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int itemsProcessed;
  final int itemsFailed;
  final String? errorMessage;

  bool get isRunning => status == SyncJobStatus.running;
  bool get hasFailed => status == SyncJobStatus.failed;
  
  Duration? get duration => completedAt?.difference(startedAt);
}

/// Model for external course link
class ExternalCourseLink {
  const ExternalCourseLink({
    required this.id,
    required this.provider,
    required this.externalCourseId,
    this.externalCourseName,
    this.sessionId,
    required this.linkedAt,
  });

  final String id;
  final String provider;
  final String externalCourseId;
  final String? externalCourseName;
  final String? sessionId;
  final DateTime linkedAt;
}

/// Model for GitHub connection
class GitHubConnection {
  const GitHubConnection({
    required this.id,
    required this.username,
    this.installationId,
    required this.connectedAt,
  });

  final String id;
  final String username;
  final String? installationId;
  final DateTime connectedAt;
}
