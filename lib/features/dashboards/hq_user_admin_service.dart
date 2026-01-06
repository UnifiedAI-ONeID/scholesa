import 'package:cloud_functions/cloud_functions.dart';

class AdminUser {
  AdminUser({
    required this.id,
    this.email,
    this.displayName,
    this.role,
    this.siteIds = const <String>[],
    this.activeSiteId,
    this.isActive,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? role;
  final List<String> siteIds;
  final String? activeSiteId;
  final bool? isActive;

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      role: map['role'] as String?,
      siteIds: (map['siteIds'] as List<dynamic>? ?? <dynamic>[]).whereType<String>().toList(),
      activeSiteId: map['activeSiteId'] as String?,
      isActive: map['isActive'] as bool?,
    );
  }
}

class HqUserAdminService {
  HttpsCallable get _listUsers => FirebaseFunctions.instance.httpsCallable('listUsers');
  HttpsCallable get _updateUserRoles => FirebaseFunctions.instance.httpsCallable('updateUserRoles');
  HttpsCallable get _resetUserPassword => FirebaseFunctions.instance.httpsCallable('resetUserPassword');
  HttpsCallable get _listAuditLogs => FirebaseFunctions.instance.httpsCallable('listAuditLogs');

  Future<List<AdminUser>> fetchUsers({String? role, String? siteId, String? email}) async {
    final result = await _listUsers.call(<String, dynamic>{
      if (role != null && role.isNotEmpty) 'role': role,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      if (email != null && email.isNotEmpty) 'email': email.toLowerCase(),
    });
    final data = result.data as Map<String, dynamic>?;
    final List<dynamic> users = data?['users'] as List<dynamic>? ?? <dynamic>[];
    return users.whereType<Map<String, dynamic>>().map(AdminUser.fromMap).toList();
  }

  Future<void> updateUser({required String uid, String? role, List<String>? siteIds, String? activeSiteId, bool? isActive}) async {
    await _updateUserRoles.call(<String, dynamic>{
      'uid': uid,
      if (role != null) 'role': role,
      if (siteIds != null) 'siteIds': siteIds,
      if (activeSiteId != null) 'activeSiteId': activeSiteId,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<String> sendReset({required String email}) async {
    final result = await _resetUserPassword.call(<String, dynamic>{'email': email});
    final data = result.data as Map<String, dynamic>?;
    return (data?['link'] as String?) ?? '';
  }

  Future<List<Map<String, dynamic>>> fetchAuditLogs({String? entityId, String? entityType, int limit = 20}) async {
    final result = await _listAuditLogs.call(<String, dynamic>{
      'limit': limit,
      if (entityId != null) 'entityId': entityId,
      if (entityType != null) 'entityType': entityType,
    });
    final data = result.data as Map<String, dynamic>?;
    final List<dynamic> logs = data?['logs'] as List<dynamic>? ?? <dynamic>[];
    return logs.whereType<Map<String, dynamic>>().toList();
  }
}
