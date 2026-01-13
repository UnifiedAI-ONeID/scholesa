import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Telemetry service for analytics and tracking
/// Based on docs/18_ANALYTICS_TELEMETRY_SPEC.md
/// 
/// Privacy rules:
/// - No PII in telemetry payloads (no names, emails, message bodies)
/// - Include siteId, role, appVersion where possible
class TelemetryService {
  TelemetryService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  String? _userId;
  String? _userRole;
  String? _siteId;
  String _appVersion = '1.0.0';

  /// Initialize telemetry with user context
  void setUserContext({
    required String userId,
    required String userRole,
    String? siteId,
    String? appVersion,
  }) {
    _userId = userId;
    _userRole = userRole;
    _siteId = siteId;
    if (appVersion != null) _appVersion = appVersion;
  }

  /// Clear user context on logout
  void clearUserContext() {
    _userId = null;
    _userRole = null;
    _siteId = null;
  }

  /// Log a telemetry event to Firestore
  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final Map<String, dynamic> eventData = <String, dynamic>{
        'event': eventName,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _userId,
        'role': _userRole,
        'siteId': _siteId,
        'appVersion': _appVersion,
        'platform': defaultTargetPlatform.name,
        ...?metadata,
      };

      // Remove any null values
      eventData.removeWhere((String key, dynamic value) => value == null);

      await _firestore.collection('telemetryEvents').add(eventData);
      debugPrint('Telemetry: $eventName');
    } catch (e) {
      // Telemetry should never crash the app
      debugPrint('Telemetry error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track user login
  Future<void> trackLogin({String? method}) async {
    await logEvent('auth.login', metadata: <String, dynamic>{
      'method': method ?? 'email',
    });
  }

  /// Track user logout
  Future<void> trackLogout() async {
    await logEvent('auth.logout');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track attendance recorded
  Future<void> trackAttendanceRecorded({
    required String sessionOccurrenceId,
    required int totalLearners,
    required int presentCount,
    bool isOffline = false,
  }) async {
    await logEvent('attendance.recorded', metadata: <String, dynamic>{
      'sessionOccurrenceId': sessionOccurrenceId,
      'totalLearners': totalLearners,
      'presentCount': presentCount,
      'attendanceRate': totalLearners > 0 
          ? (presentCount / totalLearners * 100).round() 
          : 0,
      'isOffline': isOffline,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MISSION EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track mission started
  Future<void> trackMissionStarted({
    required String missionId,
    required String pillar,
  }) async {
    await logEvent('mission.started', metadata: <String, dynamic>{
      'missionId': missionId,
      'pillar': pillar,
    });
  }

  /// Track mission attempt submitted
  Future<void> trackMissionAttemptSubmitted({
    required String missionId,
    required String pillar,
    bool hasAttachments = false,
  }) async {
    await logEvent('mission.attempt.submitted', metadata: <String, dynamic>{
      'missionId': missionId,
      'pillar': pillar,
      'hasAttachments': hasAttachments,
    });
  }

  /// Track mission completed
  Future<void> trackMissionCompleted({
    required String missionId,
    required String pillar,
    required int xpEarned,
  }) async {
    await logEvent('mission.completed', metadata: <String, dynamic>{
      'missionId': missionId,
      'pillar': pillar,
      'xpEarned': xpEarned,
    });
  }

  /// Track mission reviewed by educator
  Future<void> trackMissionReviewed({
    required String missionId,
    required int rating,
    required Duration reviewDuration,
  }) async {
    await logEvent('mission.reviewed', metadata: <String, dynamic>{
      'missionId': missionId,
      'rating': rating,
      'reviewDurationSeconds': reviewDuration.inSeconds,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track message sent (no PII - just counts)
  Future<void> trackMessageSent({
    required String threadId,
    bool hasAttachments = false,
    bool isOffline = false,
  }) async {
    await logEvent('message.sent', metadata: <String, dynamic>{
      'threadId': threadId,
      'hasAttachments': hasAttachments,
      'isOffline': isOffline,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BILLING EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track order paid
  Future<void> trackOrderPaid({
    required String orderId,
    required String productType,
    required double amount,
    required String currency,
  }) async {
    await logEvent('order.paid', metadata: <String, dynamic>{
      'orderId': orderId,
      'productType': productType,
      'amount': amount,
      'currency': currency,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CMS EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track CMS page viewed
  Future<void> trackPageViewed({
    required String pageSlug,
  }) async {
    await logEvent('cms.page.viewed', metadata: <String, dynamic>{
      'pageSlug': pageSlug,
    });
  }

  /// Track lead captured
  Future<void> trackLeadCaptured({
    required String source,
  }) async {
    await logEvent('lead.captured', metadata: <String, dynamic>{
      'source': source,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POPUP/NUDGE EVENTS (from docs/21)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track popup shown
  Future<void> trackPopupShown({
    required String popupType,
    String? context,
  }) async {
    await logEvent('popup.shown', metadata: <String, dynamic>{
      'popupType': popupType,
      'context': context,
    });
  }

  /// Track popup dismissed
  Future<void> trackPopupDismissed({
    required String popupType,
    Duration? viewDuration,
  }) async {
    await logEvent('popup.dismissed', metadata: <String, dynamic>{
      'popupType': popupType,
      'viewDurationSeconds': viewDuration?.inSeconds,
    });
  }

  /// Track popup completed (user took action)
  Future<void> trackPopupCompleted({
    required String popupType,
    required String action,
  }) async {
    await logEvent('popup.completed', metadata: <String, dynamic>{
      'popupType': popupType,
      'action': action,
    });
  }

  /// Track nudge snoozed
  Future<void> trackNudgeSnoozed({
    required String nudgeType,
    required Duration snoozeDuration,
  }) async {
    await logEvent('nudge.snoozed', metadata: <String, dynamic>{
      'nudgeType': nudgeType,
      'snoozeDurationMinutes': snoozeDuration.inMinutes,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSIGHT/SUPPORT EVENTS (from docs/22, 23)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track educator insight viewed
  Future<void> trackInsightViewed({
    required String insightType,
    required String learnerId,
  }) async {
    await logEvent('insight.viewed', metadata: <String, dynamic>{
      'insightType': insightType,
      // Note: learnerId is allowed since it's internal, not PII
      'learnerId': learnerId,
    });
  }

  /// Track support applied
  Future<void> trackSupportApplied({
    required String supportType,
    required String learnerId,
  }) async {
    await logEvent('support.applied', metadata: <String, dynamic>{
      'supportType': supportType,
      'learnerId': learnerId,
    });
  }

  /// Track support outcome logged
  Future<void> trackSupportOutcomeLogged({
    required String supportType,
    required String outcome,
    required String learnerId,
  }) async {
    await logEvent('support.outcome.logged', metadata: <String, dynamic>{
      'supportType': supportType,
      'outcome': outcome,
      'learnerId': learnerId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECKIN/CHECKOUT EVENTS (from docs/42)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track check-in
  Future<void> trackCheckin({
    required String learnerId,
    bool isOffline = false,
  }) async {
    await logEvent('presence.checkin', metadata: <String, dynamic>{
      'learnerId': learnerId,
      'isOffline': isOffline,
    });
  }

  /// Track check-out
  Future<void> trackCheckout({
    required String learnerId,
    required Duration sessionDuration,
    bool isOffline = false,
  }) async {
    await logEvent('presence.checkout', metadata: <String, dynamic>{
      'learnerId': learnerId,
      'sessionDurationMinutes': sessionDuration.inMinutes,
      'isOffline': isOffline,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HABIT EVENTS (from docs/21)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track habit logged
  Future<void> trackHabitLogged({
    required String habitId,
    required int currentStreak,
  }) async {
    await logEvent('habit.logged', metadata: <String, dynamic>{
      'habitId': habitId,
      'currentStreak': currentStreak,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARTNER/CONTRACT EVENTS (from docs/16)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track contract status change
  Future<void> trackContractStatusChange({
    required String contractId,
    required String fromStatus,
    required String toStatus,
  }) async {
    await logEvent('contract.status.changed', metadata: <String, dynamic>{
      'contractId': contractId,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
    });
  }

  /// Track deliverable submitted
  Future<void> trackDeliverableSubmitted({
    required String contractId,
    required String deliverableId,
  }) async {
    await logEvent('deliverable.submitted', metadata: <String, dynamic>{
      'contractId': contractId,
      'deliverableId': deliverableId,
    });
  }

  /// Track payout processed
  Future<void> trackPayoutProcessed({
    required String payoutId,
    required String status,
    required double amount,
  }) async {
    await logEvent('payout.processed', metadata: <String, dynamic>{
      'payoutId': payoutId,
      'status': status,
      'amount': amount,
    });
  }
}
