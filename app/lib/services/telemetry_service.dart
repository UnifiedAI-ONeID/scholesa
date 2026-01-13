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

  // ═══════════════════════════════════════════════════════════════════════════
  // SCHEDULING EVENTS (from docs/44)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track schedule viewed
  Future<void> trackScheduleViewed({
    required String viewType, // 'day', 'week'
    String? siteId,
  }) async {
    await logEvent('schedule.viewed', metadata: <String, dynamic>{
      'viewType': viewType,
      'siteId': siteId,
    });
  }

  /// Track room conflict detected
  Future<void> trackRoomConflictDetected({
    required String roomId,
    required String conflictType, // 'double_booked', 'educator_overlap'
  }) async {
    await logEvent('room.conflict.detected', metadata: <String, dynamic>{
      'roomId': roomId,
      'conflictType': conflictType,
    });
  }

  /// Track substitute requested
  Future<void> trackSubstituteRequested({
    required String sessionOccurrenceId,
    required String requestingEducatorId,
  }) async {
    await logEvent('substitute.requested', metadata: <String, dynamic>{
      'sessionOccurrenceId': sessionOccurrenceId,
      'requestingEducatorId': requestingEducatorId,
    });
  }

  /// Track substitute assigned
  Future<void> trackSubstituteAssigned({
    required String sessionOccurrenceId,
    required String substituteEducatorId,
  }) async {
    await logEvent('substitute.assigned', metadata: <String, dynamic>{
      'sessionOccurrenceId': sessionOccurrenceId,
      'substituteEducatorId': substituteEducatorId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INCIDENT EVENTS (from docs/41)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track incident created
  Future<void> trackIncidentCreated({
    required String incidentId,
    required String severity, // 'minor', 'major', 'critical'
    required String category,
  }) async {
    await logEvent('incident.created', metadata: <String, dynamic>{
      'incidentId': incidentId,
      'severity': severity,
      'category': category,
    });
  }

  /// Track incident status changed
  Future<void> trackIncidentStatusChanged({
    required String incidentId,
    required String fromStatus,
    required String toStatus,
  }) async {
    await logEvent('incident.status.changed', metadata: <String, dynamic>{
      'incidentId': incidentId,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
    });
  }

  /// Track message reported
  Future<void> trackMessageReported({
    required String messageId,
    required String reason,
  }) async {
    await logEvent('message.reported', metadata: <String, dynamic>{
      'messageId': messageId,
      'reason': reason,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CURRICULUM/RUBRIC EVENTS (from docs/45)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track mission snapshot created
  Future<void> trackMissionSnapshotCreated({
    required String missionId,
    required String snapshotId,
    required String pillar,
  }) async {
    await logEvent('mission.snapshot.created', metadata: <String, dynamic>{
      'missionId': missionId,
      'snapshotId': snapshotId,
      'pillar': pillar,
    });
  }

  /// Track rubric applied to mission attempt
  Future<void> trackRubricApplied({
    required String attemptId,
    required String rubricId,
    required int totalScore,
  }) async {
    await logEvent('rubric.applied', metadata: <String, dynamic>{
      'attemptId': attemptId,
      'rubricId': rubricId,
      'totalScore': totalScore,
    });
  }

  /// Track rubric shared to parent summary
  Future<void> trackRubricSharedToParent({
    required String attemptId,
    required String rubricId,
    required String learnerId,
  }) async {
    await logEvent('rubric.shared_to_parent_summary', metadata: <String, dynamic>{
      'attemptId': attemptId,
      'rubricId': rubricId,
      'learnerId': learnerId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT EVENTS (from docs/43)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track data export requested
  Future<void> trackExportRequested({
    required String exportType, // 'csv_roster', 'json_full', 'artifact_manifest'
    required String scope, // 'site', 'organization'
    String? siteId,
  }) async {
    await logEvent('export.requested', metadata: <String, dynamic>{
      'exportType': exportType,
      'scope': scope,
      'siteId': siteId,
    });
  }

  /// Track export download completed
  Future<void> trackExportDownloaded({
    required String exportId,
    required String exportType,
  }) async {
    await logEvent('export.downloaded', metadata: <String, dynamic>{
      'exportId': exportId,
      'exportType': exportType,
    });
  }

  /// Track deletion request
  Future<void> trackDeletionRequested({
    required String targetType, // 'learner', 'site'
    required String targetId,
    required String stage, // 'soft_delete', 'hard_delete_scheduled', 'hard_delete_completed'
  }) async {
    await logEvent('deletion.requested', metadata: <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'stage': stage,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IDENTITY MATCHING EVENTS (from docs/46)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track identity match suggested
  Future<void> trackIdentityMatchSuggested({
    required String localUserId,
    required String externalProvider,
    required double confidence,
  }) async {
    await logEvent('identity.match.suggested', metadata: <String, dynamic>{
      'localUserId': localUserId,
      'externalProvider': externalProvider,
      'confidence': confidence,
    });
  }

  /// Track identity match confirmed
  Future<void> trackIdentityMatchConfirmed({
    required String localUserId,
    required String externalProvider,
    required String externalUserId,
  }) async {
    await logEvent('identity.match.confirmed', metadata: <String, dynamic>{
      'localUserId': localUserId,
      'externalProvider': externalProvider,
      'externalUserId': externalUserId,
    });
  }

  /// Track identity match rejected/ignored
  Future<void> trackIdentityMatchRejected({
    required String localUserId,
    required String externalProvider,
    required String reason, // 'not_same_person', 'ignore'
  }) async {
    await logEvent('identity.match.rejected', metadata: <String, dynamic>{
      'localUserId': localUserId,
      'externalProvider': externalProvider,
      'reason': reason,
    });
  }

  /// Track user merge
  Future<void> trackUserMerge({
    required String primaryUserId,
    required String mergedUserId,
  }) async {
    await logEvent('identity.user.merged', metadata: <String, dynamic>{
      'primaryUserId': primaryUserId,
      'mergedUserId': mergedUserId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BILLING EVENTS (from docs/13)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track checkout session created
  Future<void> trackCheckoutStarted({
    required String productType,
    required String productId,
  }) async {
    await logEvent('billing.checkout.started', metadata: <String, dynamic>{
      'productType': productType,
      'productId': productId,
    });
  }

  /// Track subscription created
  Future<void> trackSubscriptionCreated({
    required String subscriptionId,
    required String planId,
  }) async {
    await logEvent('billing.subscription.created', metadata: <String, dynamic>{
      'subscriptionId': subscriptionId,
      'planId': planId,
    });
  }

  /// Track subscription canceled
  Future<void> trackSubscriptionCanceled({
    required String subscriptionId,
    required String reason,
  }) async {
    await logEvent('billing.subscription.canceled', metadata: <String, dynamic>{
      'subscriptionId': subscriptionId,
      'reason': reason,
    });
  }

  /// Track invoice paid
  Future<void> trackInvoicePaid({
    required String invoiceId,
    required double amount,
  }) async {
    await logEvent('billing.invoice.paid', metadata: <String, dynamic>{
      'invoiceId': invoiceId,
      'amount': amount,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARKETPLACE EVENTS (from docs/15)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track listing created
  Future<void> trackListingCreated({
    required String listingId,
    required String listingType,
  }) async {
    await logEvent('marketplace.listing.created', metadata: <String, dynamic>{
      'listingId': listingId,
      'listingType': listingType,
    });
  }

  /// Track listing submitted for approval
  Future<void> trackListingSubmitted({
    required String listingId,
  }) async {
    await logEvent('marketplace.listing.submitted', metadata: <String, dynamic>{
      'listingId': listingId,
    });
  }

  /// Track listing status changed
  Future<void> trackListingStatusChanged({
    required String listingId,
    required String fromStatus,
    required String toStatus,
  }) async {
    await logEvent('marketplace.listing.status_changed', metadata: <String, dynamic>{
      'listingId': listingId,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
    });
  }

  /// Track order created
  Future<void> trackMarketplaceOrderCreated({
    required String orderId,
    required String listingId,
  }) async {
    await logEvent('marketplace.order.created', metadata: <String, dynamic>{
      'orderId': orderId,
      'listingId': listingId,
    });
  }

  /// Track fulfillment created
  Future<void> trackFulfillmentCreated({
    required String orderId,
    required String fulfillmentId,
  }) async {
    await logEvent('marketplace.fulfillment.created', metadata: <String, dynamic>{
      'orderId': orderId,
      'fulfillmentId': fulfillmentId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION EVENTS (from docs/17)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track notification sent
  Future<void> trackNotificationSent({
    required String notificationId,
    required String notificationType,
  }) async {
    await logEvent('notification.sent', metadata: <String, dynamic>{
      'notificationId': notificationId,
      'notificationType': notificationType,
    });
  }

  /// Track notification read
  Future<void> trackNotificationRead({
    required String notificationId,
  }) async {
    await logEvent('notification.read', metadata: <String, dynamic>{
      'notificationId': notificationId,
    });
  }

  /// Track notification dismissed
  Future<void> trackNotificationDismissed({
    required String notificationId,
  }) async {
    await logEvent('notification.dismissed', metadata: <String, dynamic>{
      'notificationId': notificationId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PORTFOLIO EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track portfolio item added
  Future<void> trackPortfolioItemAdded({
    required String itemId,
    required String itemType,
    required String pillar,
  }) async {
    await logEvent('portfolio.item.added', metadata: <String, dynamic>{
      'itemId': itemId,
      'itemType': itemType,
      'pillar': pillar,
    });
  }

  /// Track portfolio item shared
  Future<void> trackPortfolioItemShared({
    required String itemId,
    required String shareTarget, // 'parent', 'public'
  }) async {
    await logEvent('portfolio.item.shared', metadata: <String, dynamic>{
      'itemId': itemId,
      'shareTarget': shareTarget,
    });
  }

  /// Track credential added
  Future<void> trackCredentialAdded({
    required String credentialId,
    required String credentialType,
  }) async {
    await logEvent('portfolio.credential.added', metadata: <String, dynamic>{
      'credentialId': credentialId,
      'credentialType': credentialType,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI DRAFT EVENTS (from docs/07)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track AI draft requested
  Future<void> trackAiDraftRequested({
    required String draftId,
    required String draftType,
  }) async {
    await logEvent('ai.draft.requested', metadata: <String, dynamic>{
      'draftId': draftId,
      'draftType': draftType,
    });
  }

  /// Track AI draft approved (human-in-the-loop)
  Future<void> trackAiDraftApproved({
    required String draftId,
    required bool wasEdited,
  }) async {
    await logEvent('ai.draft.approved', metadata: <String, dynamic>{
      'draftId': draftId,
      'wasEdited': wasEdited,
    });
  }

  /// Track AI draft rejected
  Future<void> trackAiDraftRejected({
    required String draftId,
  }) async {
    await logEvent('ai.draft.rejected', metadata: <String, dynamic>{
      'draftId': draftId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTEGRATION EVENTS (from docs/36)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track integration connected
  Future<void> trackIntegrationConnected({
    required String provider,
    required List<String> scopes,
  }) async {
    await logEvent('integration.connected', metadata: <String, dynamic>{
      'provider': provider,
      'scopeCount': scopes.length,
    });
  }

  /// Track integration disconnected
  Future<void> trackIntegrationDisconnected({
    required String provider,
  }) async {
    await logEvent('integration.disconnected', metadata: <String, dynamic>{
      'provider': provider,
    });
  }

  /// Track roster sync requested
  Future<void> trackRosterSyncRequested({
    required String provider,
    required String courseId,
  }) async {
    await logEvent('integration.roster_sync.requested', metadata: <String, dynamic>{
      'provider': provider,
      'courseId': courseId,
    });
  }

  /// Track roster sync completed
  Future<void> trackRosterSyncCompleted({
    required String provider,
    required int added,
    required int updated,
    required int paused,
  }) async {
    await logEvent('integration.roster_sync.completed', metadata: <String, dynamic>{
      'provider': provider,
      'added': added,
      'updated': updated,
      'paused': paused,
    });
  }

  /// Track attachment created (Classroom add-on)
  Future<void> trackAttachmentCreated({
    required String provider,
    required String attachmentId,
    required String missionId,
  }) async {
    await logEvent('integration.attachment.created', metadata: <String, dynamic>{
      'provider': provider,
      'attachmentId': attachmentId,
      'missionId': missionId,
    });
  }

  /// Track grade pushed to external system
  Future<void> trackGradePushed({
    required String provider,
    required String attemptId,
  }) async {
    await logEvent('integration.grade.pushed', metadata: <String, dynamic>{
      'provider': provider,
      'attemptId': attemptId,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAFETY & CONSENT EVENTS (docs/41)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track learner consent updated
  Future<void> trackConsentUpdated({
    required String learnerId,
    required bool photoCaptureAllowed,
    required bool shareWithLinkedParents,
    required bool marketingUseAllowed,
  }) async {
    await logEvent('safety.consent.updated', metadata: <String, dynamic>{
      'learnerId': learnerId,
      'photoCaptureAllowed': photoCaptureAllowed,
      'shareWithLinkedParents': shareWithLinkedParents,
      'marketingUseAllowed': marketingUseAllowed,
    });
  }

  /// Track pickup person added
  Future<void> trackPickupPersonAdded({
    required String learnerId,
    required String relationshipType,
  }) async {
    await logEvent('safety.pickup.person_added', metadata: <String, dynamic>{
      'learnerId': learnerId,
      'relationshipType': relationshipType,
    });
  }

  /// Track pickup person removed
  Future<void> trackPickupPersonRemoved({
    required String learnerId,
  }) async {
    await logEvent('safety.pickup.person_removed', metadata: <String, dynamic>{
      'learnerId': learnerId,
    });
  }

  /// Track pickup verification
  Future<void> trackPickupVerified({
    required String learnerId,
    required String pickupPersonId,
    String? verifiedBy,
  }) async {
    await logEvent('safety.pickup.verified', metadata: <String, dynamic>{
      'learnerId': learnerId,
      'pickupPersonId': pickupPersonId,
      'verifiedBy': verifiedBy,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APPROVAL EVENTS (docs/15, docs/16)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track listing approved/rejected
  Future<void> trackListingReviewed({
    required String listingId,
    required String decision,
    String? reason,
  }) async {
    await logEvent('approval.listing.$decision', metadata: <String, dynamic>{
      'listingId': listingId,
      'reason': reason,
    });
  }

  /// Track contract approved/rejected
  Future<void> trackContractReviewed({
    required String contractId,
    required String decision,
    String? reason,
  }) async {
    await logEvent('approval.contract.$decision', metadata: <String, dynamic>{
      'contractId': contractId,
      'reason': reason,
    });
  }

  /// Track payout approved/rejected
  Future<void> trackPayoutReviewed({
    required String payoutId,
    required String decision,
    required double amount,
    String? reason,
  }) async {
    await logEvent('approval.payout.$decision', metadata: <String, dynamic>{
      'payoutId': payoutId,
      'amount': amount,
      'reason': reason,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIT LOG EVENTS (docs/43)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track audit log viewed
  Future<void> trackAuditLogViewed({
    int? pageSize,
    String? filterAction,
  }) async {
    await logEvent('audit.log.viewed', metadata: <String, dynamic>{
      'pageSize': pageSize,
      'filterAction': filterAction,
    });
  }

  /// Track legal hold set
  Future<void> trackLegalHoldSet({
    required String requestId,
    required bool isHeld,
    String? reason,
  }) async {
    await logEvent('audit.legal_hold.${isHeld ? 'set' : 'released'}', metadata: <String, dynamic>{
      'requestId': requestId,
      'reason': reason,
    });
  }
}
