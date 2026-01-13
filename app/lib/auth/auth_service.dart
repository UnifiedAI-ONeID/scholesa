import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/telemetry_service.dart';
import 'app_state.dart';

/// Service for handling Firebase authentication
class AuthService {

  AuthService({
    required FirebaseAuth auth,
    required AppState appState,
    this.telemetryService,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _appState = appState,
        _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final AppState _appState;
  final FirebaseFirestore _firestore;
  final TelemetryService? telemetryService;

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _appState.setLoading(true);
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _bootstrapSession();
      
      // Track successful login telemetry
      await telemetryService?.trackLogin(method: 'email');
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      
      // Track failed login telemetry
      await telemetryService?.logEvent('auth.login_failed', metadata: <String, dynamic>{
        'method': 'email',
        'errorCode': e.code,
      });
      rethrow;
    } catch (e) {
      _appState.setError('An unexpected error occurred');
      rethrow;
    }
  }

  /// Register with email and password
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _appState.setLoading(true);
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);
      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } catch (e) {
      _appState.setError('An unexpected error occurred');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await telemetryService?.trackLogout();
    await _auth.signOut();
    _appState.clear();
  }

  /// Bootstrap session by loading user profile from Firestore
  Future<void> _bootstrapSession() async {
    try {
      final User? user = currentUser;
      if (user == null) {
        _appState.setError('No authenticated user');
        return;
      }

      // First, try to find user doc by UID
      DocumentSnapshot<Map<String, dynamic>> userDoc = 
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Check if there's an invited user doc by email
        final String inviteDocId = 'invite_${user.email?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_') ?? ''}';
        final DocumentSnapshot<Map<String, dynamic>> inviteDoc = 
            await _firestore.collection('users').doc(inviteDocId).get();
        
        if (inviteDoc.exists) {
          // Migrate invited user to real UID
          final Map<String, dynamic> inviteData = inviteDoc.data()!;
          await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
            ...inviteData,
            'email': user.email,
            'displayName': user.displayName ?? inviteData['displayName'],
            'status': 'active',
            'activatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          // Delete the invite doc
          await _firestore.collection('users').doc(inviteDocId).delete();
          // Reload the user doc
          userDoc = await _firestore.collection('users').doc(user.uid).get();
          debugPrint('Migrated invited user $inviteDocId to UID ${user.uid}');
        } else {
          // Create new user document with default role (needs admin to assign proper role)
          await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@').first,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'role': null, // No role - needs admin assignment
            'siteIds': <String>[],
          });
          // Fetch again
          userDoc = await _firestore.collection('users').doc(user.uid).get();
          debugPrint('Created new user doc for ${user.uid} - needs role assignment');
        }
      }
      
      _updateAppStateFromDoc(user.uid, userDoc.data());
    } catch (e) {
      debugPrint('Failed to bootstrap session: $e');
      _appState.setError('Failed to load user profile');
      rethrow;
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

  /// Refresh session (call /v1/me again)
  Future<void> refreshSession() async {
    if (currentUser == null) return;
    await _bootstrapSession();
  }

  /// Map Firebase auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed';
    }
  }
}
