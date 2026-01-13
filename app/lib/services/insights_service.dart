import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'telemetry_service.dart';

/// Service for educator insights and learner support strategies
/// Based on docs/23_TEACHER_SUPPORT_INSIGHTS_SPEC.md
/// 
/// Collections:
/// - sessionInsights/{sessionOccurrenceId}
/// - learnerInsights/{learnerId}
/// - supportInterventions/{id}
/// - configs/supportStrategies
class InsightsService extends ChangeNotifier {
  InsightsService({
    this.educatorId,
    this.siteId,
    this.telemetryService,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String? educatorId;
  final String? siteId;
  final TelemetryService? telemetryService;

  // State
  SessionInsights? _currentSessionInsights;
  Map<String, LearnerInsight> _learnerInsights = <String, LearnerInsight>{};
  List<SupportIntervention> _interventions = <SupportIntervention>[];
  List<SupportStrategy> _strategies = <SupportStrategy>[];
  bool _isLoading = false;
  String? _error;

  // Getters
  SessionInsights? get currentSessionInsights => _currentSessionInsights;
  Map<String, LearnerInsight> get learnerInsights => _learnerInsights;
  List<SupportIntervention> get interventions => _interventions;
  List<SupportStrategy> get strategies => _strategies;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─────────────────────────────────────────────────────────────────────────────
  // Session Insights (Class Heatmap)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load insights for a session occurrence
  Future<void> loadSessionInsights(String sessionOccurrenceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('sessionInsights')
          .doc(sessionOccurrenceId)
          .get();

      if (doc.exists) {
        _currentSessionInsights = SessionInsights.fromMap(doc.id, doc.data()!);
      } else {
        _currentSessionInsights = null;
      }
    } catch (e) {
      _error = 'Failed to load session insights: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Learner Insights (Learner Snapshot)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load insight for a specific learner
  Future<LearnerInsight?> loadLearnerInsight(String learnerId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('learnerInsights')
          .doc(learnerId)
          .get();

      if (doc.exists) {
        final LearnerInsight insight = LearnerInsight.fromMap(doc.id, doc.data()!);
        _learnerInsights[learnerId] = insight;
        notifyListeners();

        // Track telemetry
        telemetryService?.trackInsightViewed(
          insightType: 'learner_snapshot',
          learnerId: learnerId,
        );

        return insight;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading learner insight: $e');
      return null;
    }
  }

  /// Load insights for multiple learners (batch)
  Future<void> loadLearnerInsightsBatch(List<String> learnerIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Firestore doesn't support whereIn with more than 10 items
      final List<List<String>> batches = <List<String>>[];
      for (int i = 0; i < learnerIds.length; i += 10) {
        batches.add(learnerIds.sublist(
          i,
          i + 10 > learnerIds.length ? learnerIds.length : i + 10,
        ));
      }

      for (final List<String> batch in batches) {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('learnerInsights')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
          _learnerInsights[doc.id] = LearnerInsight.fromMap(doc.id, doc.data());
        }
      }
    } catch (e) {
      debugPrint('Error loading learner insights batch: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Support Interventions (Intervention Logger)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load intervention history for a learner
  Future<void> loadInterventions(String learnerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('supportInterventions')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('appliedAt', descending: true)
          .limit(20)
          .get();

      _interventions = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return SupportIntervention.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      debugPrint('Error loading interventions: $e');
      _interventions = <SupportIntervention>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log a new support intervention
  Future<bool> logIntervention({
    required String learnerId,
    required String strategyId,
    required String strategyName,
    String? notes,
  }) async {
    if (educatorId == null) return false;

    try {
      await _firestore.collection('supportInterventions').add(<String, dynamic>{
        'learnerId': learnerId,
        'educatorId': educatorId,
        'siteId': siteId,
        'strategyId': strategyId,
        'strategyName': strategyName,
        'notes': notes,
        'outcome': null, // Set later
        'appliedAt': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      telemetryService?.trackSupportApplied(
        supportType: strategyName,
        learnerId: learnerId,
      );

      return true;
    } catch (e) {
      debugPrint('Error logging intervention: $e');
      return false;
    }
  }

  /// Update intervention outcome
  Future<bool> updateInterventionOutcome({
    required String interventionId,
    required InterventionOutcome outcome,
    String? notes,
  }) async {
    try {
      await _firestore.collection('supportInterventions').doc(interventionId).update(<String, dynamic>{
        'outcome': outcome.name,
        'outcomeNotes': notes,
        'outcomeAt': FieldValue.serverTimestamp(),
      });

      // Track telemetry
      final SupportIntervention intervention = _interventions.firstWhere(
        (SupportIntervention i) => i.id == interventionId,
        orElse: () => SupportIntervention(
          id: interventionId,
          learnerId: '',
          educatorId: '',
          strategyId: '',
          strategyName: 'unknown',
          appliedAt: DateTime.now(),
        ),
      );

      telemetryService?.trackSupportOutcomeLogged(
        supportType: intervention.strategyName,
        outcome: outcome.name,
        learnerId: intervention.learnerId,
      );

      return true;
    } catch (e) {
      debugPrint('Error updating intervention outcome: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Support Strategies (configs/supportStrategies)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load available support strategies
  Future<void> loadStrategies() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('configs')
          .doc('supportStrategies')
          .get();

      if (doc.exists) {
        final List<dynamic> strategiesData = doc.data()!['strategies'] as List<dynamic>? ?? <dynamic>[];
        _strategies = strategiesData.map((dynamic s) {
          if (s is Map<String, dynamic>) {
            return SupportStrategy.fromMap(s);
          }
          return SupportStrategy(id: '', name: 'Unknown', category: '');
        }).toList();
      } else {
        // Use defaults
        _strategies = SupportStrategy.defaults();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading strategies: $e');
      _strategies = SupportStrategy.defaults();
      notifyListeners();
    }
  }

  /// Get top suggestions for a learner based on their insights
  List<SupportStrategy> getSuggestionsForLearner(String learnerId) {
    final LearnerInsight? insight = _learnerInsights[learnerId];
    if (insight == null) return _strategies.take(3).toList();

    // Filter strategies by learner's needs
    final List<SupportStrategy> suggestions = <SupportStrategy>[];

    // Add strategies matching learner's challenges
    for (final String challenge in insight.currentChallenges) {
      final List<SupportStrategy> matching = _strategies.where(
        (SupportStrategy s) => s.targetChallenges.contains(challenge),
      ).toList();
      suggestions.addAll(matching);
    }

    // Remove duplicates and limit
    return suggestions.toSet().take(5).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

/// Session insights - class-wide heatmap
class SessionInsights {
  SessionInsights({
    required this.sessionOccurrenceId,
    required this.topCheckins,
    required this.classwideNotes,
    this.suggestionsFocus,
    this.updatedAt,
  });

  factory SessionInsights.fromMap(String id, Map<String, dynamic> data) {
    return SessionInsights(
      sessionOccurrenceId: id,
      topCheckins: List<String>.from(data['topCheckins'] as List<dynamic>? ?? <dynamic>[]),
      classwideNotes: data['classwideNotes'] as String? ?? '',
      suggestionsFocus: data['suggestionsFocus'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String sessionOccurrenceId;
  final List<String> topCheckins;
  final String classwideNotes;
  final String? suggestionsFocus;
  final DateTime? updatedAt;
}

/// Learner insight - individual snapshot
class LearnerInsight {
  LearnerInsight({
    required this.learnerId,
    required this.habitLoopSummary,
    required this.currentChallenges,
    required this.recentSupports,
    this.tryThisToday,
    this.updatedAt,
  });

  factory LearnerInsight.fromMap(String id, Map<String, dynamic> data) {
    return LearnerInsight(
      learnerId: id,
      habitLoopSummary: data['habitLoopSummary'] as String? ?? '',
      currentChallenges: List<String>.from(data['currentChallenges'] as List<dynamic>? ?? <dynamic>[]),
      recentSupports: List<String>.from(data['recentSupports'] as List<dynamic>? ?? <dynamic>[]),
      tryThisToday: data['tryThisToday'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String learnerId;
  final String habitLoopSummary;
  final List<String> currentChallenges;
  final List<String> recentSupports;
  final String? tryThisToday;
  final DateTime? updatedAt;
}

/// Support intervention record
class SupportIntervention {
  SupportIntervention({
    required this.id,
    required this.learnerId,
    required this.educatorId,
    required this.strategyId,
    required this.strategyName,
    required this.appliedAt,
    this.siteId,
    this.notes,
    this.outcome,
    this.outcomeNotes,
    this.outcomeAt,
  });

  factory SupportIntervention.fromMap(String id, Map<String, dynamic> data) {
    return SupportIntervention(
      id: id,
      learnerId: data['learnerId'] as String? ?? '',
      educatorId: data['educatorId'] as String? ?? '',
      strategyId: data['strategyId'] as String? ?? '',
      strategyName: data['strategyName'] as String? ?? '',
      siteId: data['siteId'] as String?,
      notes: data['notes'] as String?,
      outcome: data['outcome'] != null
          ? InterventionOutcome.values.firstWhere(
              (InterventionOutcome o) => o.name == data['outcome'],
              orElse: () => InterventionOutcome.unknown,
            )
          : null,
      outcomeNotes: data['outcomeNotes'] as String?,
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      outcomeAt: (data['outcomeAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String learnerId;
  final String educatorId;
  final String strategyId;
  final String strategyName;
  final String? siteId;
  final String? notes;
  final InterventionOutcome? outcome;
  final String? outcomeNotes;
  final DateTime appliedAt;
  final DateTime? outcomeAt;
}

/// Intervention outcome enum
enum InterventionOutcome {
  helped,
  didNotHelp,
  needsAdjustment,
  unknown,
}

/// Support strategy definition
class SupportStrategy {
  SupportStrategy({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.targetChallenges = const <String>[],
  });

  factory SupportStrategy.fromMap(Map<String, dynamic> data) {
    return SupportStrategy(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String?,
      targetChallenges: List<String>.from(data['targetChallenges'] as List<dynamic>? ?? <dynamic>[]),
    );
  }

  /// Default support strategies
  static List<SupportStrategy> defaults() {
    return <SupportStrategy>[
      SupportStrategy(
        id: 'checkin_support',
        name: 'Daily Check-in',
        category: 'Social-Emotional',
        description: 'Brief 1:1 check-in at start of class',
        targetChallenges: <String>['anxiety', 'disengagement'],
      ),
      SupportStrategy(
        id: 'extended_time',
        name: 'Extended Time',
        category: 'Academic',
        description: 'Extra time for assignments and assessments',
        targetChallenges: <String>['processing', 'attention'],
      ),
      SupportStrategy(
        id: 'movement_breaks',
        name: 'Movement Breaks',
        category: 'Behavioral',
        description: 'Scheduled breaks for physical movement',
        targetChallenges: <String>['attention', 'hyperactivity'],
      ),
      SupportStrategy(
        id: 'peer_buddy',
        name: 'Peer Buddy',
        category: 'Social',
        description: 'Pair with supportive peer for activities',
        targetChallenges: <String>['social', 'confidence'],
      ),
      SupportStrategy(
        id: 'visual_aids',
        name: 'Visual Aids',
        category: 'Academic',
        description: 'Use visual supports and graphic organizers',
        targetChallenges: <String>['processing', 'organization'],
      ),
      SupportStrategy(
        id: 'clear_transitions',
        name: 'Clear Transitions',
        category: 'Behavioral',
        description: 'Advance notice and structured transitions',
        targetChallenges: <String>['transitions', 'anxiety'],
      ),
      SupportStrategy(
        id: 'positive_reinforcement',
        name: 'Positive Reinforcement',
        category: 'Behavioral',
        description: 'Frequent specific praise and encouragement',
        targetChallenges: <String>['motivation', 'confidence'],
      ),
      SupportStrategy(
        id: 'quiet_space',
        name: 'Quiet Space',
        category: 'Environment',
        description: 'Access to low-stimulation work area',
        targetChallenges: <String>['sensory', 'attention'],
      ),
    ];
  }

  final String id;
  final String name;
  final String category;
  final String? description;
  final List<String> targetChallenges;
}
