import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../auth/app_state.dart' show UserRole;
import 'user_models.dart';

/// Service for HQ user administration
class UserAdminService extends ChangeNotifier {

  UserAdminService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.currentUserId,
    this.currentUserEmail,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String? currentUserId;
  final String? currentUserEmail;

  List<UserModel> _users = <UserModel>[];
  List<SiteModel> _sites = <SiteModel>[];
  List<AuditLogEntry> _auditLogs = <AuditLogEntry>[];
  bool _isLoading = false;
  String? _error;
  
  // Filters
  UserRole? _roleFilter;
  UserStatus? _statusFilter;
  String? _siteFilter;
  String _searchQuery = '';

  // Getters
  List<UserModel> get users => _filteredUsers;
  List<SiteModel> get sites => _sites;
  List<AuditLogEntry> get auditLogs => _auditLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserRole? get roleFilter => _roleFilter;
  UserStatus? get statusFilter => _statusFilter;
  String? get siteFilter => _siteFilter;
  String get searchQuery => _searchQuery;

  List<UserModel> get _filteredUsers {
    return _users.where((UserModel user) {
      // Role filter
      if (_roleFilter != null && user.role != _roleFilter) return false;
      
      // Status filter
      if (_statusFilter != null && user.status != _statusFilter) return false;
      
      // Site filter
      if (_siteFilter != null && !user.siteIds.contains(_siteFilter)) return false;
      
      // Search query
      if (_searchQuery.isNotEmpty) {
        final String query = _searchQuery.toLowerCase();
        final bool matchesEmail = user.email.toLowerCase().contains(query);
        final bool matchesName = user.displayName?.toLowerCase().contains(query) ?? false;
        if (!matchesEmail && !matchesName) return false;
      }
      
      return true;
    }).toList();
  }

  // Stats
  int get totalUsers => _users.length;
  int get activeUsers => _users.where((UserModel u) => u.status == UserStatus.active).length;
  int get suspendedUsers => _users.where((UserModel u) => u.status == UserStatus.suspended).length;
  int get learnerCount => _users.where((UserModel u) => u.role == UserRole.learner).length;
  int get educatorCount => _users.where((UserModel u) => u.role == UserRole.educator).length;

  // Filter setters
  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setStatusFilter(UserStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSiteFilter(String? siteId) {
    _siteFilter = siteId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _roleFilter = null;
    _statusFilter = null;
    _siteFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Load all users (HQ only) from Firebase
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load users from Firestore
      final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
          .collection('users')
          .get();
      
      _users = usersSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return UserModel(
          uid: doc.id,
          email: data['email'] as String? ?? '',
          displayName: data['displayName'] as String?,
          photoURL: data['photoURL'] as String?,
          role: _parseUserRole(data['role'] as String?),
          status: _parseUserStatus(data['status'] as String?),
          siteIds: List<String>.from(data['siteIds'] as List<dynamic>? ?? <dynamic>[]),
          parentIds: List<String>.from(data['parentIds'] as List<dynamic>? ?? <dynamic>[]),
          organizationId: data['organizationId'] as String?,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
      
      // Load sites from Firestore
      final QuerySnapshot<Map<String, dynamic>> sitesSnapshot = await _firestore
          .collection('sites')
          .get();
      
      _sites = await Future.wait(sitesSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
        final Map<String, dynamic> data = doc.data();
        
        // Count users and learners for this site
        final int userCount = _users.where((UserModel u) => u.siteIds.contains(doc.id)).length;
        final int learnerCount = _users.where((UserModel u) => u.siteIds.contains(doc.id) && u.role == UserRole.learner).length;
        
        return SiteModel(
          id: doc.id,
          name: data['name'] as String? ?? '',
          location: data['location'] as String?,
          siteLeadIds: List<String>.from(data['siteLeadIds'] as List<dynamic>? ?? <dynamic>[]),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          userCount: userCount,
          learnerCount: learnerCount,
        );
      }));
    } catch (e) {
      _error = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate a deterministic user doc ID from email (for invited users)
  String _generateUserDocId(String email) {
    // Use a simple hash of the email for pending invites
    return 'invite_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
  }

  UserRole _parseUserRole(String? role) {
    switch (role) {
      case 'hq':
        return UserRole.hq;
      case 'educator':
        return UserRole.educator;
      case 'site':
        return UserRole.site;
      case 'learner':
        return UserRole.learner;
      case 'parent':
        return UserRole.parent;
      case 'partner':
        return UserRole.partner;
      default:
        return UserRole.learner;
    }
  }

  UserStatus _parseUserStatus(String? status) {
    switch (status) {
      case 'active':
        return UserStatus.active;
      case 'pending':
        return UserStatus.pending;
      case 'suspended':
        return UserStatus.suspended;
      case 'deactivated':
        return UserStatus.deactivated;
      default:
        return UserStatus.active;
    }
  }

  /// Load audit logs from Firebase
  Future<void> loadAuditLogs({String? userId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(100);
      
      if (userId != null) {
        query = query.where('entityId', isEqualTo: userId);
      }
      
      final QuerySnapshot<Map<String, dynamic>> logsSnapshot = await query.get();
      
      _auditLogs = logsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return AuditLogEntry(
          id: doc.id,
          actorId: data['actorId'] as String? ?? '',
          actorEmail: data['actorEmail'] as String? ?? '',
          action: data['action'] as String? ?? '',
          entityType: data['entityType'] as String? ?? '',
          entityId: data['entityId'] as String? ?? '',
          siteId: data['siteId'] as String?,
          details: Map<String, String>.from(data['details'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{}),
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load audit logs: $e');
    }
  }

  /// Create a new user in Firebase
  /// Note: This creates a Firestore user profile that must be linked to Firebase Auth
  /// The user will need to be created in Firebase Auth separately (via invite flow or registration)
  Future<UserModel?> createUser({
    required String email,
    required String displayName,
    required UserRole role,
    required List<String> siteIds,
    String? uid, // Optional: pre-assigned UID from Firebase Auth
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      
      // Generate a temporary ID if no UID provided
      // The ID will be the email hash to allow lookup before Auth is created
      final String docId = uid ?? _generateUserDocId(email);
      
      await _firestore.collection('users').doc(docId).set(<String, dynamic>{
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'status': uid != null ? UserStatus.active.name : UserStatus.pending.name,
        'siteIds': siteIds,
        'createdAt': Timestamp.fromDate(now),
        'invitedAt': uid == null ? Timestamp.fromDate(now) : null,
      }, SetOptions(merge: true));

      // Log the action
      await _logAuditAction(
        action: 'user.created',
        entityType: 'User',
        entityId: docId,
        siteId: siteIds.isNotEmpty ? siteIds.first : null,
      );

      final UserModel newUser = UserModel(
        uid: docId,
        email: email,
        displayName: displayName,
        role: role,
        status: uid != null ? UserStatus.active : UserStatus.pending,
        siteIds: siteIds,
        createdAt: now,
      );
      
      _users = <UserModel>[..._users, newUser];
      return newUser;
    } catch (e) {
      _error = 'Failed to create user: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new user with password via Cloud Function
  /// This creates both the Firebase Auth user and Firestore profile
  Future<UserModel?> createUserWithPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required List<String> siteIds,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final HttpsCallable callable = _functions.httpsCallable('createUserWithPassword');
      final HttpsCallableResult<dynamic> result = await callable.call(<String, dynamic>{
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role.name,
        'siteIds': siteIds,
      });

      final Map<String, dynamic> data = Map<String, dynamic>.from(result.data as Map);
      
      if (data['success'] == true) {
        final String uid = data['uid'] as String;
        final DateTime now = DateTime.now();
        
        // Log the action
        await _logAuditAction(
          action: 'user.created_with_password',
          entityType: 'User',
          entityId: uid,
          siteId: siteIds.isNotEmpty ? siteIds.first : null,
          details: <String, String>{'email': email, 'role': role.name},
        );

        final UserModel newUser = UserModel(
          uid: uid,
          email: email,
          displayName: displayName,
          role: role,
          siteIds: siteIds,
          createdAt: now,
        );
        
        _users = <UserModel>[..._users, newUser];
        return newUser;
      } else {
        _error = data['error']?.toString() ?? 'Failed to create user';
        return null;
      }
    } catch (e) {
      _error = 'Failed to create user: $e';
      debugPrint('createUserWithPassword error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user role in Firebase
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      final DateTime now = DateTime.now();
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel oldUser = _users[index];
      
      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'role': newRole.name,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.role_updated',
        entityType: 'User',
        entityId: userId,
        siteId: oldUser.siteIds.isNotEmpty ? oldUser.siteIds.first : null,
        details: <String, String>{'oldRole': oldUser.role.name, 'newRole': newRole.name},
      );

      _users[index] = oldUser.copyWith(role: newRole, updatedAt: now);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update user role: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update user status in Firebase (suspend/reactivate)
  Future<bool> updateUserStatus(String userId, UserStatus newStatus) async {
    try {
      final DateTime now = DateTime.now();
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel oldUser = _users[index];

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'status': newStatus.name,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.status_updated',
        entityType: 'User',
        entityId: userId,
        siteId: oldUser.siteIds.isNotEmpty ? oldUser.siteIds.first : null,
        details: <String, String>{'oldStatus': oldUser.status.name, 'newStatus': newStatus.name},
      );

      _users[index] = oldUser.copyWith(status: newStatus, updatedAt: now);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update user status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add user to site in Firebase
  Future<bool> addUserToSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel user = _users[index];
      if (user.siteIds.contains(siteId)) return true;

      final List<String> newSiteIds = <String>[...user.siteIds, siteId];
      final DateTime now = DateTime.now();

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'siteIds': newSiteIds,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.site_added',
        entityType: 'User',
        entityId: userId,
        siteId: siteId,
      );

      _users[index] = user.copyWith(siteIds: newSiteIds, updatedAt: now);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add user to site: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove user from site in Firebase
  Future<bool> removeUserFromSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel user = _users[index];
      final List<String> newSiteIds = user.siteIds.where((String s) => s != siteId).toList();
      final DateTime now = DateTime.now();

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'siteIds': newSiteIds,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.site_removed',
        entityType: 'User',
        entityId: userId,
        siteId: siteId,
      );

      _users[index] = user.copyWith(siteIds: newSiteIds, updatedAt: now);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove user from site: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete user (deactivate)
  Future<bool> deleteUser(String userId) async {
    return updateUserStatus(userId, UserStatus.deactivated);
  }

  /// Helper to log audit actions
  Future<void> _logAuditAction({
    required String action,
    required String entityType,
    required String entityId,
    String? siteId,
    Map<String, String>? details,
  }) async {
    if (currentUserId == null) {
      debugPrint('Cannot log audit: no authenticated user');
      return;
    }
    try {
      await _firestore.collection('audit_logs').add(<String, dynamic>{
        'actorId': currentUserId,
        'actorEmail': currentUserEmail ?? 'unknown',
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'siteId': siteId,
        'details': details ?? <String, String>{},
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Failed to log audit action: $e');
    }
  }
}
