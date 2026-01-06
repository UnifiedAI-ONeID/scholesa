import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.role,
    this.siteIds = const <String>[],
    this.activeSiteId,
    this.isActive,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? role;
  final List<String> siteIds;
  final String? activeSiteId;
  final bool? isActive;
}

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UserProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: data['displayName'] as String?,
      role: data['role'] as String?,
      siteIds: (data['siteIds'] as List<dynamic>? ?? <dynamic>[]).whereType<String>().toList(),
      activeSiteId: data['activeSiteId'] as String?,
      isActive: data['isActive'] as bool?,
    );
  }
}
