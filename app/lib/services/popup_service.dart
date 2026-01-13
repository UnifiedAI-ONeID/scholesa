import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'telemetry_service.dart';

/// Popup/Nudge service for micro-coaching based on docs/21_PILLAR_HABIT_ENGINE_POPUPS_SPEC.md
/// 
/// Surfaces:
/// - modal (rare, blocking)
/// - bottom sheet (primary guided action)
/// - snackbar (light reminder)
class PopupService extends ChangeNotifier {
  PopupService({
    this.userId,
    this.userRole,
    this.telemetryService,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String? userId;
  final String? userRole;
  final TelemetryService? telemetryService;

  // Popup state
  final Map<String, NudgeState> _nudgeStates = <String, NudgeState>{};
  PopupConfig? _config;
  bool _isLoading = false;

  // Anti-annoyance tracking
  final Map<String, DateTime> _lastShownTimes = <String, DateTime>{};
  final Map<String, int> _showCounts = <String, int>{};

  // Do-not-interrupt contexts
  static const Set<String> _doNotInterruptContexts = <String>{
    'attendance',
    'checkout',
    'uploading',
    'recording',
    'reviewing',
  };

  String? _currentContext;

  // Getters
  bool get isLoading => _isLoading;
  PopupConfig? get config => _config;

  /// Set the current context (for do-not-interrupt logic)
  void setContext(String? context) {
    _currentContext = context;
    notifyListeners();
  }

  /// Check if interrupts are allowed in the current context
  bool get canShowPopups {
    if (_currentContext == null) return true;
    return !_doNotInterruptContexts.contains(_currentContext);
  }

  /// Load popup configuration from Firestore
  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      final DocumentSnapshot<Map<String, dynamic>> configDoc = await _firestore
          .collection('configs')
          .doc('popupRules')
          .get();

      if (configDoc.exists) {
        final Map<String, dynamic> data = configDoc.data()!;
        _config = PopupConfig.fromMap(data);
      } else {
        // Use defaults
        _config = PopupConfig.defaults();
      }
    } catch (e) {
      debugPrint('Error loading popup config: $e');
      _config = PopupConfig.defaults();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load nudge state for the current user
  Future<void> loadNudgeState() async {
    if (userId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nudgeState')
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        _nudgeStates[doc.id] = NudgeState.fromMap(doc.id, data);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading nudge state: $e');
    }
  }

  /// Check if a popup should be shown based on config and anti-annoyance rules
  bool shouldShowPopup(PopupType type) {
    if (!canShowPopups) return false;
    if (_config == null) return false;

    final String popupId = type.id;
    final PopupRule? rule = _config!.rules[popupId];
    if (rule == null || !rule.enabled) return false;

    // Check cooldown
    final DateTime? lastShown = _lastShownTimes[popupId];
    if (lastShown != null) {
      final Duration elapsed = DateTime.now().difference(lastShown);
      if (elapsed < rule.cooldown) return false;
    }

    // Check daily cap
    final int showCount = _showCounts[popupId] ?? 0;
    if (showCount >= rule.dailyCap) return false;

    // Check if snoozed
    final NudgeState? state = _nudgeStates[popupId];
    if (state != null && state.isSnoozed) return false;

    return true;
  }

  /// Record that a popup was shown
  Future<void> recordPopupShown(PopupType type, {String? context}) async {
    final String popupId = type.id;
    
    _lastShownTimes[popupId] = DateTime.now();
    _showCounts[popupId] = (_showCounts[popupId] ?? 0) + 1;

    // Track telemetry
    telemetryService?.trackPopupShown(
      popupType: popupId,
      context: context,
    );

    // Update remote state
    if (userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('nudgeState')
            .doc(popupId)
            .set(<String, dynamic>{
          'lastShown': FieldValue.serverTimestamp(),
          'showCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating nudge state: $e');
      }
    }

    notifyListeners();
  }

  /// Record that a popup was dismissed
  Future<void> recordPopupDismissed(PopupType type, {Duration? viewDuration}) async {
    telemetryService?.trackPopupDismissed(
      popupType: type.id,
      viewDuration: viewDuration,
    );
  }

  /// Record that a popup action was completed
  Future<void> recordPopupCompleted(PopupType type, String action) async {
    telemetryService?.trackPopupCompleted(
      popupType: type.id,
      action: action,
    );

    // Mark as completed in state
    if (userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('nudgeState')
            .doc(type.id)
            .set(<String, dynamic>{
          'completed': true,
          'completedAt': FieldValue.serverTimestamp(),
          'action': action,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating nudge completion: $e');
      }
    }
  }

  /// Snooze a popup for a specified duration
  Future<void> snoozePopup(PopupType type, Duration snoozeDuration) async {
    final String popupId = type.id;
    final DateTime snoozeUntil = DateTime.now().add(snoozeDuration);

    _nudgeStates[popupId] = NudgeState(
      popupId: popupId,
      snoozedUntil: snoozeUntil,
      lastShown: DateTime.now(),
    );

    // Track telemetry
    telemetryService?.trackNudgeSnoozed(
      nudgeType: popupId,
      snoozeDuration: snoozeDuration,
    );

    // Update remote state
    if (userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('nudgeState')
            .doc(popupId)
            .set(<String, dynamic>{
          'snoozedUntil': Timestamp.fromDate(snoozeUntil),
          'lastSnoozed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving snooze state: $e');
      }
    }

    notifyListeners();
  }

  /// Get the next popup to show for the current role
  PopupType? getNextPopup() {
    if (!canShowPopups) return null;

    final List<PopupType> rolePopups = PopupType.forRole(userRole ?? '');
    for (final PopupType type in rolePopups) {
      if (shouldShowPopup(type)) {
        return type;
      }
    }
    return null;
  }
}

/// Popup types catalog from docs/21
enum PopupType {
  // Learner popups
  learnerPlan('POP-LRN-PLAN', 'learner', 'Weekly commitment chooser'),
  learnerEvidence('POP-LRN-EVIDENCE', 'learner', 'Capture proof before leaving class'),
  learnerReflect('POP-LRN-REFLECT', 'learner', '60 sec reflection after evidence'),
  learnerImprove('POP-LRN-IMPROVE', 'learner', 'Next step after educator review'),

  // Educator popups
  educatorPlan('POP-EDU-PLAN', 'educator', 'Mission plan prompt'),
  educatorReview('POP-EDU-REVIEW', 'educator', 'Review queue reminder'),

  // Parent popups
  parentSummary('POP-PAR-SUMMARY', 'parent', 'Weekly summary + support action'),

  // Admin popups
  adminProvision('POP-ADM-PROVISION', 'site', 'Blocking if provisioning incomplete');

  const PopupType(this.id, this.role, this.description);

  final String id;
  final String role;
  final String description;

  /// Get all popup types for a role
  static List<PopupType> forRole(String role) {
    return PopupType.values.where((PopupType t) => t.role == role).toList();
  }
}

/// Nudge state for tracking popup interactions
class NudgeState {
  NudgeState({
    required this.popupId,
    this.snoozedUntil,
    this.lastShown,
    this.showCount = 0,
    this.completed = false,
  });

  factory NudgeState.fromMap(String id, Map<String, dynamic> data) {
    return NudgeState(
      popupId: id,
      snoozedUntil: (data['snoozedUntil'] as Timestamp?)?.toDate(),
      lastShown: (data['lastShown'] as Timestamp?)?.toDate(),
      showCount: data['showCount'] as int? ?? 0,
      completed: data['completed'] as bool? ?? false,
    );
  }

  final String popupId;
  final DateTime? snoozedUntil;
  final DateTime? lastShown;
  final int showCount;
  final bool completed;

  bool get isSnoozed {
    if (snoozedUntil == null) return false;
    return DateTime.now().isBefore(snoozedUntil!);
  }
}

/// Popup configuration from Firestore configs/popupRules
class PopupConfig {
  PopupConfig({required this.rules});

  factory PopupConfig.fromMap(Map<String, dynamic> data) {
    final Map<String, PopupRule> rules = <String, PopupRule>{};
    final Map<String, dynamic>? rulesData = data['rules'] as Map<String, dynamic>?;
    
    if (rulesData != null) {
      for (final MapEntry<String, dynamic> entry in rulesData.entries) {
        if (entry.value is Map<String, dynamic>) {
          rules[entry.key] = PopupRule.fromMap(entry.value as Map<String, dynamic>);
        }
      }
    }
    
    return PopupConfig(rules: rules);
  }

  factory PopupConfig.defaults() {
    return PopupConfig(rules: <String, PopupRule>{
      for (final PopupType type in PopupType.values)
        type.id: PopupRule(
          enabled: true,
          cooldown: const Duration(hours: 4),
          dailyCap: 3,
          surface: PopupSurface.bottomSheet,
        ),
    });
  }

  final Map<String, PopupRule> rules;
}

/// Rule for a specific popup type
class PopupRule {
  PopupRule({
    required this.enabled,
    required this.cooldown,
    required this.dailyCap,
    required this.surface,
  });

  factory PopupRule.fromMap(Map<String, dynamic> data) {
    return PopupRule(
      enabled: data['enabled'] as bool? ?? true,
      cooldown: Duration(minutes: data['cooldownMinutes'] as int? ?? 240),
      dailyCap: data['dailyCap'] as int? ?? 3,
      surface: PopupSurface.values.firstWhere(
        (PopupSurface s) => s.name == data['surface'],
        orElse: () => PopupSurface.bottomSheet,
      ),
    );
  }

  final bool enabled;
  final Duration cooldown;
  final int dailyCap;
  final PopupSurface surface;
}

/// Popup surface types from docs/21
enum PopupSurface {
  modal,      // rare, blocking
  bottomSheet, // primary guided action
  snackbar,   // light reminder
}
