import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Safety service for consent management and pickup authorization
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
/// 
/// Covers:
/// - Media/artifact consent per learner
/// - Pickup authorization lists
/// - Emergency contacts
class SafetyService extends ChangeNotifier {
  SafetyService({
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

  List<LearnerConsent> _consents = <LearnerConsent>[];
  List<PickupAuthorization> _pickupAuths = <PickupAuthorization>[];
  bool _isLoading = false;
  String? _error;

  List<LearnerConsent> get consents => _consents;
  List<PickupAuthorization> get pickupAuths => _pickupAuths;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSENT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load consents for site (admin view)
  Future<void> loadConsentsForSite() async {
    if (siteId == null) return;
    if (userRole != 'site' && userRole != 'hq') {
      _error = 'Unauthorized: Admin role required';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('learnerConsents')
          .where('siteId', isEqualTo: siteId)
          .orderBy('updatedAt', descending: true)
          .get();

      _consents = snapshot.docs.map(_parseConsentDoc).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('SafetyService.loadConsentsForSite error: $e');
    }
  }

  /// Get consent for a specific learner
  Future<LearnerConsent?> getConsentForLearner(String learnerId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('learnerConsents')
          .where('learnerId', isEqualTo: learnerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _parseConsentDoc(snapshot.docs.first);
    } catch (e) {
      debugPrint('SafetyService.getConsentForLearner error: $e');
      return null;
    }
  }

  /// Update learner consent (admin-only)
  Future<bool> updateConsent({
    required String learnerId,
    required bool photoCaptureAllowed,
    required bool shareWithLinkedParents,
    required bool marketingUseAllowed,
    DateTime? consentStartDate,
    DateTime? consentEndDate,
    String? consentDocumentUrl,
  }) async {
    if (userRole != 'site' && userRole != 'hq') {
      _error = 'Unauthorized: Admin role required';
      notifyListeners();
      return false;
    }

    try {
      // Check if consent doc exists
      final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
          .collection('learnerConsents')
          .where('learnerId', isEqualTo: learnerId)
          .limit(1)
          .get();

      final Map<String, dynamic> consentData = <String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'photoCaptureAllowed': photoCaptureAllowed,
        'shareWithLinkedParents': shareWithLinkedParents,
        'marketingUseAllowed': marketingUseAllowed,
        'consentStartDate': consentStartDate != null ? Timestamp.fromDate(consentStartDate) : null,
        'consentEndDate': consentEndDate != null ? Timestamp.fromDate(consentEndDate) : null,
        'consentDocumentUrl': consentDocumentUrl,
        'updatedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String docId;
      if (existing.docs.isNotEmpty) {
        docId = existing.docs.first.id;
        await _firestore.collection('learnerConsents').doc(docId).update(consentData);
      } else {
        consentData['createdAt'] = FieldValue.serverTimestamp();
        final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('learnerConsents').add(consentData);
        docId = docRef.id;
      }

      // Write audit log
      await _writeAuditLog(
        action: 'consent.updated',
        targetId: learnerId,
        metadata: <String, dynamic>{
          'photoCaptureAllowed': photoCaptureAllowed,
          'shareWithLinkedParents': shareWithLinkedParents,
          'marketingUseAllowed': marketingUseAllowed,
        },
      );

      await telemetryService.logEvent('safety.consent.updated', metadata: <String, dynamic>{
        'learnerId': learnerId,
        'photoCaptureAllowed': photoCaptureAllowed,
      });

      await loadConsentsForSite();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('SafetyService.updateConsent error: $e');
      return false;
    }
  }

  /// Check if photo capture is allowed for learner
  Future<bool> isPhotoCaptureAllowed(String learnerId) async {
    final LearnerConsent? consent = await getConsentForLearner(learnerId);
    return consent?.photoCaptureAllowed ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PICKUP AUTHORIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load pickup authorizations for site
  Future<void> loadPickupAuthsForSite() async {
    if (siteId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('pickupAuthorizations')
          .where('siteId', isEqualTo: siteId)
          .orderBy('updatedAt', descending: true)
          .get();

      _pickupAuths = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return PickupAuthorization(
          id: doc.id,
          learnerId: data['learnerId'] as String? ?? '',
          authorizedPersons: (data['authorizedPersons'] as List<dynamic>?)
              ?.map((dynamic p) => AuthorizedPerson.fromMap(p as Map<String, dynamic>))
              .toList() ?? <AuthorizedPerson>[],
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('SafetyService.loadPickupAuthsForSite error: $e');
    }
  }

  /// Get pickup authorizations for a learner
  Future<List<AuthorizedPerson>> getPickupAuthsForLearner(String learnerId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('pickupAuthorizations')
          .where('learnerId', isEqualTo: learnerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return <AuthorizedPerson>[];

      final Map<String, dynamic> data = snapshot.docs.first.data();
      return (data['authorizedPersons'] as List<dynamic>?)
          ?.map((dynamic p) => AuthorizedPerson.fromMap(p as Map<String, dynamic>))
          .toList() ?? <AuthorizedPerson>[];
    } catch (e) {
      debugPrint('SafetyService.getPickupAuthsForLearner error: $e');
      return <AuthorizedPerson>[];
    }
  }

  /// Add authorized pickup person (admin-only)
  Future<bool> addAuthorizedPerson({
    required String learnerId,
    required String fullName,
    required String relationship,
    required String phone,
    String? idCheckNotes,
  }) async {
    if (userRole != 'site' && userRole != 'hq') {
      _error = 'Unauthorized: Admin role required';
      notifyListeners();
      return false;
    }

    try {
      // Get existing or create new
      final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
          .collection('pickupAuthorizations')
          .where('learnerId', isEqualTo: learnerId)
          .limit(1)
          .get();

      final Map<String, dynamic> newPerson = <String, dynamic>{
        'fullName': fullName,
        'relationship': relationship,
        'phone': phone,
        'idCheckNotes': idCheckNotes,
        'addedAt': DateTime.now().toIso8601String(),
        'addedBy': userId,
      };

      if (existing.docs.isNotEmpty) {
        await _firestore.collection('pickupAuthorizations').doc(existing.docs.first.id).update(<String, dynamic>{
          'authorizedPersons': FieldValue.arrayUnion(<Map<String, dynamic>>[newPerson]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('pickupAuthorizations').add(<String, dynamic>{
          'learnerId': learnerId,
          'siteId': siteId,
          'authorizedPersons': <Map<String, dynamic>>[newPerson],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Write audit log
      await _writeAuditLog(
        action: 'pickup_auth.added',
        targetId: learnerId,
        metadata: <String, dynamic>{
          'personName': fullName,
          'relationship': relationship,
        },
      );

      await loadPickupAuthsForSite();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('SafetyService.addAuthorizedPerson error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  LearnerConsent _parseConsentDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return LearnerConsent(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      photoCaptureAllowed: data['photoCaptureAllowed'] as bool? ?? false,
      shareWithLinkedParents: data['shareWithLinkedParents'] as bool? ?? false,
      marketingUseAllowed: data['marketingUseAllowed'] as bool? ?? false, // defaults false per spec
      consentStartDate: (data['consentStartDate'] as Timestamp?)?.toDate(),
      consentEndDate: (data['consentEndDate'] as Timestamp?)?.toDate(),
      consentDocumentUrl: data['consentDocumentUrl'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<void> _writeAuditLog({
    required String action,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': action,
        'targetId': targetId,
        'userId': userId,
        'siteId': siteId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('SafetyService._writeAuditLog error: $e');
    }
  }
}

/// Model for learner consent
class LearnerConsent {
  const LearnerConsent({
    required this.id,
    required this.learnerId,
    required this.photoCaptureAllowed,
    required this.shareWithLinkedParents,
    required this.marketingUseAllowed,
    this.consentStartDate,
    this.consentEndDate,
    this.consentDocumentUrl,
    required this.updatedAt,
  });

  final String id;
  final String learnerId;
  final bool photoCaptureAllowed;
  final bool shareWithLinkedParents;
  final bool marketingUseAllowed;
  final DateTime? consentStartDate;
  final DateTime? consentEndDate;
  final String? consentDocumentUrl;
  final DateTime updatedAt;

  /// Check if consent is currently valid
  bool get isValid {
    final DateTime now = DateTime.now();
    if (consentStartDate != null && now.isBefore(consentStartDate!)) return false;
    if (consentEndDate != null && now.isAfter(consentEndDate!)) return false;
    return true;
  }
}

/// Model for pickup authorization
class PickupAuthorization {
  const PickupAuthorization({
    required this.id,
    required this.learnerId,
    required this.authorizedPersons,
    required this.updatedAt,
  });

  final String id;
  final String learnerId;
  final List<AuthorizedPerson> authorizedPersons;
  final DateTime updatedAt;
}

/// Model for authorized person
class AuthorizedPerson {
  const AuthorizedPerson({
    required this.fullName,
    required this.relationship,
    required this.phone,
    this.idCheckNotes,
  });

  final String fullName;
  final String relationship;
  final String phone;
  final String? idCheckNotes;

  factory AuthorizedPerson.fromMap(Map<String, dynamic> map) {
    return AuthorizedPerson(
      fullName: map['fullName'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      idCheckNotes: map['idCheckNotes'] as String?,
    );
  }
}
