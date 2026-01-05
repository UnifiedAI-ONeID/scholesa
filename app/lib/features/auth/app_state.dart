import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class AppState extends ChangeNotifier {
  AppState({AuthServiceBase? authService}) : _authService = authService ?? AuthService();

  final AuthServiceBase _authService;
  User? _user;
  String? _role;
  Set<String> _entitlements = const {'learner'};
  List<String> _siteIds = const <String>[];
  String? _primarySiteId;

  User? get user => _user;
  String? get role => _role;
  bool get isAuthenticated => _user != null;
  Set<String> get entitlements => _entitlements;
  List<String> get siteIds => _siteIds;
  String? get primarySiteId => _primarySiteId;

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  void setRole(String role) {
    _role = role;
    notifyListeners();
  }

  void clearRole() {
    _role = null;
    notifyListeners();
  }

  void clearAuth() {
    _user = null;
    _role = null;
    _entitlements = const {'learner'};
    _siteIds = const <String>[];
    _primarySiteId = null;
    notifyListeners();
  }

  Future<void> refreshEntitlements() async {
    final result = await _authService.loadEntitlements();
    _entitlements = result.roles.isNotEmpty ? result.roles : const {'learner'};
    _siteIds = result.siteIds;
    _primarySiteId = result.primarySiteId;
    notifyListeners();
  }
}
