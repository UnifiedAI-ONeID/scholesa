import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/telemetry_service.dart';
import 'parent_models.dart';

/// Service for parent-specific views - LIVE DATA FROM FIREBASE
class ParentService extends ChangeNotifier {

  ParentService({
    this.parentId,
    FirebaseFirestore? firestore,
    this.telemetryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final String? parentId;
  final TelemetryService? telemetryService;

  List<LearnerSummary> _learnerSummaries = <LearnerSummary>[];
  BillingSummary? _billingSummary;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LearnerSummary> get learnerSummaries => _learnerSummaries;
  BillingSummary? get billingSummary => _billingSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all data for parent dashboard from Firebase
  Future<void> loadParentData() async {
    if (parentId == null) {
      _error = "Not logged in. Please log in to view your children's data.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadLinkedLearners();
      await _loadBillingData();
      
      // Track telemetry for dashboard view
      await telemetryService?.logEvent('parent.dashboard_viewed', metadata: <String, dynamic>{
        'learnerCount': _learnerSummaries.length,
      });
    } catch (e) {
      _error = 'Failed to load parent data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load learners linked to this parent via guardian_links
  Future<void> _loadLinkedLearners() async {
    if (parentId == null) return;
    final String currentParentId = parentId!;

    final QuerySnapshot<Map<String, dynamic>> linksSnapshot = await _firestore
        .collection('guardian_links')
        .where('parentId', isEqualTo: currentParentId)
        .get();

    if (linksSnapshot.docs.isEmpty) {
      _learnerSummaries = <LearnerSummary>[];
      return;
    }

    final List<String> learnerIds = linksSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => 
            doc.data()['learnerId'] as String)
        .toList();

    final List<LearnerSummary> summaries = <LearnerSummary>[];
    for (final String learnerId in learnerIds) {
      final LearnerSummary? summary = await _loadLearnerSummary(learnerId);
      if (summary != null) summaries.add(summary);
    }
    _learnerSummaries = summaries;
  }

  /// Load a single learner's summary from Firebase
  Future<LearnerSummary?> _loadLearnerSummary(String learnerId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
          .collection('users').doc(learnerId).get();
      if (!userDoc.exists) return null;
      final Map<String, dynamic> userData = userDoc.data()!;

      final DocumentSnapshot<Map<String, dynamic>> progressDoc = await _firestore
          .collection('learner_progress').doc(learnerId).get();
      final Map<String, dynamic>? progressData = progressDoc.data();

      final QuerySnapshot<Map<String, dynamic>> activitiesSnapshot = await _firestore
          .collection('activity_logs')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('timestamp', descending: true)
          .limit(5).get();
      final List<RecentActivity> recentActivities = activitiesSnapshot.docs
          .map(_parseActivity).toList();

      final DateTime now = DateTime.now();
      final QuerySnapshot<Map<String, dynamic>> eventsSnapshot = await _firestore
          .collection('calendar_events')
          .where('participantIds', arrayContains: learnerId)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dateTime').limit(5).get();
      final List<UpcomingEvent> upcomingEvents = eventsSnapshot.docs
          .map(_parseEvent).toList();

      final double attendanceRate = await _calculateAttendanceRate(learnerId);

      return LearnerSummary(
        learnerId: learnerId,
        learnerName: userData['displayName'] as String? ?? 'Unknown',
        photoUrl: userData['photoUrl'] as String?,
        currentLevel: (progressData?['level'] as int?) ?? 1,
        totalXp: (progressData?['totalXp'] as int?) ?? 0,
        missionsCompleted: (progressData?['missionsCompleted'] as int?) ?? 0,
        currentStreak: (progressData?['currentStreak'] as int?) ?? 0,
        attendanceRate: attendanceRate,
        recentActivities: recentActivities,
        upcomingEvents: upcomingEvents,
        pillarProgress: <String, double>{
          'futureSkills': (progressData?['futureSkillsProgress'] as num?)?.toDouble() ?? 0.0,
          'leadership': (progressData?['leadershipProgress'] as num?)?.toDouble() ?? 0.0,
          'impact': (progressData?['impactProgress'] as num?)?.toDouble() ?? 0.0,
        },
      );
    } catch (e) {
      debugPrint('Error loading learner $learnerId: $e');
      return null;
    }
  }

  RecentActivity _parseActivity(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return RecentActivity(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'activity',
      emoji: data['emoji'] as String? ?? '📝',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  UpcomingEvent _parseEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return UpcomingEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] as String? ?? 'event',
      location: data['location'] as String?,
    );
  }

  Future<double> _calculateAttendanceRate(String learnerId) async {
    try {
      final DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('attendance_records')
          .where('learnerId', isEqualTo: learnerId)
          .where('recordedAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      if (snapshot.docs.isEmpty) return 0.0;
      int present = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final String status = doc.data()['status'] as String? ?? '';
        if (status == 'present' || status == 'late') present++;
      }
      return present / snapshot.docs.length;
    } catch (e) {
      return 0.0;
    }
  }

  /// Load billing data from Firebase
  Future<void> _loadBillingData() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> subDoc = await _firestore
          .collection('subscriptions').doc(parentId).get();
      if (!subDoc.exists) {
        _billingSummary = const BillingSummary(
          currentBalance: 0.0, nextPaymentAmount: 0.0, subscriptionPlan: 'Free');
        return;
      }
      final Map<String, dynamic> subData = subDoc.data()!;
      final QuerySnapshot<Map<String, dynamic>> paymentsSnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: parentId)
          .orderBy('date', descending: true).limit(5).get();
      final List<PaymentHistory> payments = paymentsSnapshot.docs
          .map(_parsePayment).toList();
      _billingSummary = BillingSummary(
        currentBalance: (subData['balance'] as num?)?.toDouble() ?? 0.0,
        nextPaymentAmount: (subData['nextPaymentAmount'] as num?)?.toDouble() ?? 0.0,
        nextPaymentDate: (subData['nextPaymentDate'] as Timestamp?)?.toDate(),
        subscriptionPlan: subData['plan'] as String? ?? 'Free',
        recentPayments: payments,
      );
    } catch (e) {
      _billingSummary = const BillingSummary(
        currentBalance: 0.0, nextPaymentAmount: 0.0, subscriptionPlan: 'Free');
    }
  }

  PaymentHistory _parsePayment(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return PaymentHistory(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'unknown',
      description: data['description'] as String? ?? 'Payment',
    );
  }

  // ========== Schedule Data ==========
  List<UpcomingEvent> _scheduleEvents = <UpcomingEvent>[];
  List<UpcomingEvent> get scheduleEvents => _scheduleEvents;

  /// Load schedule for linked learners from Firebase
  Future<void> loadSchedule({DateTime? startDate, DateTime? endDate}) async {
    if (parentId == null) return;
    
    try {
      final DateTime start = startDate ?? DateTime.now();
      final DateTime end = endDate ?? start.add(const Duration(days: 30));

      // Get learner IDs linked to this parent
      final QuerySnapshot<Map<String, dynamic>> linksSnapshot = await _firestore
          .collection('guardian_links')
          .where('parentId', isEqualTo: parentId)
          .get();

      if (linksSnapshot.docs.isEmpty) {
        _scheduleEvents = <UpcomingEvent>[];
        notifyListeners();
        return;
      }

      final List<String> learnerIds = linksSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => 
              doc.data()['learnerId'] as String)
          .toList();

      final List<UpcomingEvent> allEvents = <UpcomingEvent>[];

      // Query session occurrences for each learner
      for (final String learnerId in learnerIds) {
        // Get enrollments for this learner
        final QuerySnapshot<Map<String, dynamic>> enrollmentsSnapshot = await _firestore
            .collection('enrollments')
            .where('learnerId', isEqualTo: learnerId)
            .where('status', isEqualTo: 'active')
            .get();

        final List<String> sessionIds = enrollmentsSnapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => 
                doc.data()['sessionId'] as String)
            .toList();

        if (sessionIds.isEmpty) continue;

        // Get session occurrences
        final QuerySnapshot<Map<String, dynamic>> occurrencesSnapshot = await _firestore
            .collection('sessionOccurrences')
            .where('sessionId', whereIn: sessionIds.take(10).toList()) // Firestore limit
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('startTime', isLessThan: Timestamp.fromDate(end))
            .orderBy('startTime')
            .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in occurrencesSnapshot.docs) {
          final Map<String, dynamic> data = doc.data();
          allEvents.add(UpcomingEvent(
            id: doc.id,
            title: data['title'] as String? ?? 'Session',
            description: data['description'] as String?,
            dateTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            type: 'class',
            location: data['roomName'] as String?,
          ));
        }
      }

      // Also get calendar events for learners
      final QuerySnapshot<Map<String, dynamic>> calendarSnapshot = await _firestore
          .collection('calendar_events')
          .where('participantIds', arrayContainsAny: learnerIds.take(10).toList())
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThan: Timestamp.fromDate(end))
          .orderBy('dateTime')
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in calendarSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        allEvents.add(UpcomingEvent(
          id: doc.id,
          title: data['title'] as String? ?? 'Event',
          description: data['description'] as String?,
          dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: data['type'] as String? ?? 'event',
          location: data['location'] as String?,
        ));
      }

      // Sort by date
      allEvents.sort((UpcomingEvent a, UpcomingEvent b) => a.dateTime.compareTo(b.dateTime));
      _scheduleEvents = allEvents;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading schedule: $e');
      _scheduleEvents = <UpcomingEvent>[];
      notifyListeners();
    }
  }

  /// Check if a date has events
  bool hasEventsOnDate(DateTime date) {
    final DateTime dateOnly = DateTime(date.year, date.month, date.day);
    return _scheduleEvents.any((UpcomingEvent event) {
      final DateTime eventDate = DateTime(event.dateTime.year, event.dateTime.month, event.dateTime.day);
      return eventDate.isAtSameMomentAs(dateOnly);
    });
  }

  /// Get events for a specific date
  List<UpcomingEvent> getEventsForDate(DateTime date) {
    final DateTime dateOnly = DateTime(date.year, date.month, date.day);
    return _scheduleEvents.where((UpcomingEvent event) {
      final DateTime eventDate = DateTime(event.dateTime.year, event.dateTime.month, event.dateTime.day);
      return eventDate.isAtSameMomentAs(dateOnly);
    }).toList();
  }

  Future<void> refresh() => loadParentData();
}
