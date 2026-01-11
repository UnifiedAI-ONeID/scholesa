import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/app_state.dart';

/// Bootstraps the app session after Firebase init
class SessionBootstrap {

  SessionBootstrap({
    required FirebaseAuth auth,
    required AppState appState,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _appState = appState,
        _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final AppState _appState;
  final FirebaseFirestore _firestore;

  /// Initialize session - call after Firebase.initializeApp()
  Future<void> initialize() async {
    _appState.setLoading(true);
    
    // Check if user is already signed in
    final User? user = _auth.currentUser;
    if (user == null) {
      _appState.setLoading(false);
      return;
    }

    try {
      // Fetch user profile from Firestore
      final DocumentSnapshot<Map<String, dynamic>> userDoc = 
          await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@').first,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });
        // Fetch again
        final DocumentSnapshot<Map<String, dynamic>> newDoc = 
            await _firestore.collection('users').doc(user.uid).get();
        _updateAppStateFromDoc(user.uid, newDoc.data());
      } else {
        _updateAppStateFromDoc(user.uid, userDoc.data());
      }
    } catch (e) {
      debugPrint('Session bootstrap failed: $e');
      _appState.setError('Failed to load profile. Please try again.');
    }
  }

  /// Update AppState from Firestore document
  void _updateAppStateFromDoc(String odId, Map<String, dynamic>? data) {
    if (data == null) return;
    _appState.updateFromMeResponse(<String, dynamic>{
      'userId': odId,
      'email': data['email'] as String?,
      'displayName': data['displayName'] as String?,
      'role': data['role'] as String?,
      'activeSiteId': data['activeSiteId'] as String?,
      'siteIds': data['siteIds'] as List<dynamic>? ?? <dynamic>[],
    });
  }

  /// Listen to auth state changes and bootstrap/clear accordingly
  void listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        _appState.clear();
      } else {
        await initialize();
      }
    });
  }
}
