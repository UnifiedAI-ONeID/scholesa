import 'package:flutter/foundation.dart';

import '../dashboards/user_profile_service.dart';

class AppState extends ChangeNotifier {
  String? _role;
  UserProfile? _profile;

  String? get role => _role ?? _profile?.role;
  UserProfile? get profile => _profile;

  void setRole(String role) {
    _role = role;
    notifyListeners();
  }

  void setProfile(UserProfile profile) {
    _profile = profile;
    _role ??= profile.role;
    notifyListeners();
  }

  void clearAll() {
    _role = null;
    _profile = null;
    notifyListeners();
  }
}
