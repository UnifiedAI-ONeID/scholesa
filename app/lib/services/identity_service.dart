import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Identity resolution service for matching external accounts
/// Based on docs/46_IDENTITY_MATCHING_RESOLUTION_SPEC.md
/// 
/// Capabilities:
/// - Load unmatched external users
/// - Confirm/reject identity matches
/// - Merge duplicate users (admin only)
/// - Track all changes to audit log
class IdentityService extends ChangeNotifier {
  IdentityService({
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

  List<IdentityMatch> _pendingMatches = <IdentityMatch>[];
  bool _isLoading = false;
  String? _error;

  List<IdentityMatch> get pendingMatches => _pendingMatches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load pending identity matches for site
  Future<void> loadPendingMatches() async {
    if (siteId == null && userRole != 'hq') return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('identityMatches');
      
      // Filter by site unless HQ
      if (siteId != null && userRole != 'hq') {
        query = query.where('siteId', isEqualTo: siteId);
      }

      query = query
          .where('status', isEqualTo: 'pending')
          .orderBy('suggestedAt', descending: true)
          .limit(100);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _pendingMatches = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return IdentityMatch(
          id: doc.id,
          localUserId: data['localUserId'] as String? ?? '',
          localUserName: data['localUserName'] as String? ?? '',
          externalUserId: data['externalUserId'] as String? ?? '',
          externalUserName: data['externalUserName'] as String? ?? '',
          provider: data['provider'] as String? ?? 'unknown',
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          matchReasons: List<String>.from(data['matchReasons'] as List? ?? <String>[]),
          status: data['status'] as String? ?? 'pending',
          suggestedAt: (data['suggestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          siteId: data['siteId'] as String?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('IdentityService.loadPendingMatches error: $e');
    }
  }

  /// Confirm an identity match
  Future<bool> confirmMatch(String matchId) async {
    if (userId == null) return false;

    final IdentityMatch match = _pendingMatches.firstWhere(
      (IdentityMatch m) => m.id == matchId,
      orElse: () => IdentityMatch(
        id: matchId,
        localUserId: '',
        localUserName: '',
        externalUserId: '',
        externalUserName: '',
        provider: 'unknown',
        confidence: 0.0,
        matchReasons: <String>[],
        status: 'pending',
        suggestedAt: DateTime.now(),
      ),
    );

    try {
      // Update match status
      await _firestore.collection('identityMatches').doc(matchId).update(<String, dynamic>{
        'status': 'confirmed',
        'confirmedBy': userId,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      // Create external identity link
      await _firestore.collection('externalIdentityLinks').add(<String, dynamic>{
        'localUserId': match.localUserId,
        'externalUserId': match.externalUserId,
        'provider': match.provider,
        'linkedAt': FieldValue.serverTimestamp(),
        'linkedBy': userId,
        'siteId': siteId,
      });

      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'identity_match_confirmed',
        'actor': userId,
        'target': matchId,
        'details': <String, dynamic>{
          'localUserId': match.localUserId,
          'externalUserId': match.externalUserId,
          'provider': match.provider,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      await telemetryService.trackIdentityMatchConfirmed(
        localUserId: match.localUserId,
        externalProvider: match.provider,
        externalUserId: match.externalUserId,
      );

      // Remove from local list
      _pendingMatches.removeWhere((IdentityMatch m) => m.id == matchId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('IdentityService.confirmMatch error: $e');
      return false;
    }
  }

  /// Reject an identity match
  Future<bool> rejectMatch(String matchId, {String reason = 'not_same_person'}) async {
    if (userId == null) return false;

    final IdentityMatch match = _pendingMatches.firstWhere(
      (IdentityMatch m) => m.id == matchId,
      orElse: () => IdentityMatch(
        id: matchId,
        localUserId: '',
        localUserName: '',
        externalUserId: '',
        externalUserName: '',
        provider: 'unknown',
        confidence: 0.0,
        matchReasons: <String>[],
        status: 'pending',
        suggestedAt: DateTime.now(),
      ),
    );

    try {
      // Update match status
      await _firestore.collection('identityMatches').doc(matchId).update(<String, dynamic>{
        'status': reason == 'ignore' ? 'ignored' : 'rejected',
        'rejectedBy': userId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectReason': reason,
      });

      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'identity_match_rejected',
        'actor': userId,
        'target': matchId,
        'details': <String, dynamic>{
          'localUserId': match.localUserId,
          'provider': match.provider,
          'reason': reason,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      await telemetryService.trackIdentityMatchRejected(
        localUserId: match.localUserId,
        externalProvider: match.provider,
        reason: reason,
      );

      // Remove from local list
      _pendingMatches.removeWhere((IdentityMatch m) => m.id == matchId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('IdentityService.rejectMatch error: $e');
      return false;
    }
  }

  /// Merge duplicate users (HQ/admin only)
  Future<bool> mergeUsers({
    required String primaryUserId,
    required String mergedUserId,
  }) async {
    if (userId == null || (userRole != 'hq' && userRole != 'site_lead')) {
      _error = 'Permission denied: only HQ or site admin can merge users';
      notifyListeners();
      return false;
    }

    try {
      // Create merge request (handled by backend)
      await _firestore.collection('userMergeRequests').add(<String, dynamic>{
        'primaryUserId': primaryUserId,
        'mergedUserId': mergedUserId,
        'status': 'pending',
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'siteId': siteId,
      });

      // Log to audit
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'user_merge_requested',
        'actor': userId,
        'target': mergedUserId,
        'details': <String, dynamic>{
          'primaryUserId': primaryUserId,
          'mergedUserId': mergedUserId,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      await telemetryService.trackUserMerge(
        primaryUserId: primaryUserId,
        mergedUserId: mergedUserId,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('IdentityService.mergeUsers error: $e');
      return false;
    }
  }
}

/// Model for identity match
class IdentityMatch {
  const IdentityMatch({
    required this.id,
    required this.localUserId,
    required this.localUserName,
    required this.externalUserId,
    required this.externalUserName,
    required this.provider,
    required this.confidence,
    required this.matchReasons,
    required this.status,
    required this.suggestedAt,
    this.siteId,
  });

  final String id;
  final String localUserId;
  final String localUserName;
  final String externalUserId;
  final String externalUserName;
  final String provider;
  final double confidence;
  final List<String> matchReasons;
  final String status;
  final DateTime suggestedAt;
  final String? siteId;

  bool get isHighConfidence => confidence >= 0.85;
  bool get isMediumConfidence => confidence >= 0.65 && confidence < 0.85;
  bool get isLowConfidence => confidence < 0.65;
}
