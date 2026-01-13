import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/telemetry_service.dart';
import 'provisioning_models.dart';

/// Service for user provisioning operations - LIVE DATA FROM FIREBASE
class ProvisioningService extends ChangeNotifier {

  ProvisioningService({
    FirebaseFirestore? firestore,
    this.telemetryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final TelemetryService? telemetryService;

  List<LearnerProfile> _learners = <LearnerProfile>[];
  List<ParentProfile> _parents = <ParentProfile>[];
  List<GuardianLink> _guardianLinks = <GuardianLink>[];
  bool _isLoading = false;
  String? _error;

  List<LearnerProfile> get learners => _learners;
  List<ParentProfile> get parents => _parents;
  List<GuardianLink> get guardianLinks => _guardianLinks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load learners for site from Firestore
  Future<void> loadLearners(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .where('siteIds', arrayContains: siteId)
          .where('role', isEqualTo: 'learner')
          .get();

      _learners = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return LearnerProfile(
          id: doc.id,
          siteId: siteId,
          userId: doc.id,
          displayName: data['displayName'] as String? ?? '',
          gradeLevel: data['gradeLevel'] as int?,
          dateOfBirth: _parseTimestamp(data['dateOfBirth']),
          notes: data['notes'] as String?,
        );
      }).toList();
    } catch (e) {
      _error = 'Failed to load learners: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load parents for site from Firestore
  Future<void> loadParents(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .where('siteIds', arrayContains: siteId)
          .where('role', isEqualTo: 'parent')
          .get();

      _parents = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return ParentProfile(
          id: doc.id,
          siteId: siteId,
          userId: doc.id,
          displayName: data['displayName'] as String? ?? '',
          phone: data['phone'] as String?,
          email: data['email'] as String?,
        );
      }).toList();
    } catch (e) {
      _error = 'Failed to load parents: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load guardian links for site from Firestore
  Future<void> loadGuardianLinks(String siteId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('guardian_links')
          .where('siteId', isEqualTo: siteId)
          .get();

      _guardianLinks = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return GuardianLink(
          id: doc.id,
          siteId: siteId,
          parentId: data['parentId'] as String? ?? '',
          learnerId: data['learnerId'] as String? ?? '',
          relationship: data['relationship'] as String? ?? 'guardian',
          isPrimary: data['isPrimary'] as bool? ?? false,
          createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
          createdBy: data['createdBy'] as String? ?? '',
          parentName: data['parentName'] as String?,
          learnerName: data['learnerName'] as String?,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load guardian links: $e');
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  /// Create learner profile in Firestore
  Future<LearnerProfile?> createLearner({
    required String siteId,
    required String email,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore
          .collection('users')
          .add(<String, dynamic>{
            'email': email,
            'displayName': displayName,
            'role': 'learner',
            'siteIds': <String>[siteId],
            if (gradeLevel != null) 'gradeLevel': gradeLevel,
            if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
            if (notes != null) 'notes': notes,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      final LearnerProfile learner = LearnerProfile(
        id: docRef.id,
        siteId: siteId,
        userId: docRef.id,
        displayName: displayName,
        gradeLevel: gradeLevel,
        dateOfBirth: dateOfBirth,
        notes: notes,
      );
      _learners.add(learner);
      
      // Track telemetry
      await telemetryService?.logEvent('provisioning.learner_created', metadata: <String, dynamic>{
        'siteId': siteId,
        'learnerId': docRef.id,
      });
      
      notifyListeners();
      return learner;
    } catch (e) {
      _error = 'Failed to create learner: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create parent profile in Firestore
  Future<ParentProfile?> createParent({
    required String siteId,
    required String email,
    required String displayName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore
          .collection('users')
          .add(<String, dynamic>{
            'email': email,
            'displayName': displayName,
            'role': 'parent',
            'siteIds': <String>[siteId],
            if (phone != null) 'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      final ParentProfile parent = ParentProfile(
        id: docRef.id,
        siteId: siteId,
        userId: docRef.id,
        displayName: displayName,
        phone: phone,
        email: email,
      );
      _parents.add(parent);
      
      // Track telemetry
      await telemetryService?.logEvent('provisioning.parent_created', metadata: <String, dynamic>{
        'siteId': siteId,
        'parentId': docRef.id,
      });
      
      notifyListeners();
      return parent;
    } catch (e) {
      _error = 'Failed to create parent: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create guardian link in Firestore
  Future<GuardianLink?> createGuardianLink({
    required String siteId,
    required String parentId,
    required String learnerId,
    required String relationship,
    required String createdBy,
    bool isPrimary = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get parent and learner names for denormalization
      final DocumentSnapshot<Map<String, dynamic>> parentDoc = 
          await _firestore.collection('users').doc(parentId).get();
      final DocumentSnapshot<Map<String, dynamic>> learnerDoc = 
          await _firestore.collection('users').doc(learnerId).get();

      final String? parentName = parentDoc.data()?['displayName'] as String?;
      final String? learnerName = learnerDoc.data()?['displayName'] as String?;

      final DocumentReference<Map<String, dynamic>> docRef = await _firestore
          .collection('guardian_links')
          .add(<String, dynamic>{
            'siteId': siteId,
            'parentId': parentId,
            'learnerId': learnerId,
            'relationship': relationship,
            'isPrimary': isPrimary,
            'parentName': parentName,
            'learnerName': learnerName,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': createdBy,
          });

      final GuardianLink link = GuardianLink(
        id: docRef.id,
        siteId: siteId,
        parentId: parentId,
        learnerId: learnerId,
        relationship: relationship,
        isPrimary: isPrimary,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        parentName: parentName,
        learnerName: learnerName,
      );
      _guardianLinks.add(link);
      
      // Track telemetry
      await telemetryService?.logEvent('provisioning.guardian_link_created', metadata: <String, dynamic>{
        'siteId': siteId,
        'parentId': parentId,
        'learnerId': learnerId,
        'relationship': relationship,
      });
      
      notifyListeners();
      return link;
    } catch (e) {
      _error = 'Failed to create guardian link: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete guardian link from Firestore
  Future<bool> deleteGuardianLink(String linkId) async {
    try {
      final GuardianLink? linkToDelete = _guardianLinks.where((GuardianLink l) => l.id == linkId).firstOrNull;
      await _firestore.collection('guardian_links').doc(linkId).delete();
      _guardianLinks.removeWhere((GuardianLink l) => l.id == linkId);
      
      // Track telemetry
      await telemetryService?.logEvent('provisioning.guardian_link_deleted', metadata: <String, dynamic>{
        'linkId': linkId,
        'parentId': linkToDelete?.parentId,
        'learnerId': linkToDelete?.learnerId,
      });
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete guardian link: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
