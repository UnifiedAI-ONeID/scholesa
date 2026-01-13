import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// AI Draft service for human-in-the-loop AI assistance
/// Based on docs/07_AI_HUMAN_IN_LOOP_POLICY.md
/// 
/// Core policy:
/// - AI is ONLY for drafting assistance
/// - NEVER auto-send, auto-grade, or auto-approve
/// - Every AI output must show: why (signals), confidence, editable content
/// - All drafts stored with status: DRAFT|APPROVED|REJECTED, reviewedBy, reviewedAt
class AiDraftService extends ChangeNotifier {
  AiDraftService({
    required this.telemetryService,
    this.userId,
    this.userRole,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? userRole;
  final FirebaseFirestore _firestore;

  List<AiDraft> _drafts = <AiDraft>[];
  bool _isLoading = false;
  String? _error;

  List<AiDraft> get drafts => _drafts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load drafts for user
  Future<void> loadDrafts() async {
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('aiDrafts')
          .where('requestedBy', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      _drafts = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return AiDraft(
          id: doc.id,
          draftType: data['draftType'] as String? ?? 'unknown',
          status: _parseStatus(data['status'] as String?),
          content: data['content'] as String? ?? '',
          signals: List<String>.from(data['signals'] as List<dynamic>? ?? <dynamic>[]),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          contextId: data['contextId'] as String?,
          requestedBy: data['requestedBy'] as String?,
          requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          reviewedBy: data['reviewedBy'] as String?,
          reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
          editedContent: data['editedContent'] as String?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('AiDraftService.loadDrafts error: $e');
    }
  }

  /// Request a new AI draft
  /// Allowed types (per docs/07):
  /// - feedback: Teacher feedback wording
  /// - parent_summary: Weekly parent summary
  /// - support_strategy: Learner support suggestions
  /// - learner_commitment: Commitment suggestions
  Future<AiDraft?> requestDraft({
    required String draftType,
    required String contextId,
    Map<String, dynamic>? inputSignals,
  }) async {
    if (userId == null) return null;

    // Validate draft type
    if (!_allowedDraftTypes.contains(draftType)) {
      _error = 'Draft type "$draftType" is not allowed';
      notifyListeners();
      return null;
    }

    try {
      // In production, this would call a Cloud Function to generate the draft
      // For now, create a placeholder that the API will populate
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('aiDrafts').add(<String, dynamic>{
        'draftType': draftType,
        'status': AiDraftStatus.pending.name,
        'contextId': contextId,
        'inputSignals': inputSignals,
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.logEvent('ai.draft.requested', metadata: <String, dynamic>{
        'draftId': docRef.id,
        'draftType': draftType,
      });

      final AiDraft draft = AiDraft(
        id: docRef.id,
        draftType: draftType,
        status: AiDraftStatus.pending,
        content: '',
        signals: <String>[],
        confidence: 0.0,
        contextId: contextId,
        requestedBy: userId,
        requestedAt: DateTime.now(),
      );

      _drafts.insert(0, draft);
      notifyListeners();

      return draft;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AiDraftService.requestDraft error: $e');
      return null;
    }
  }

  /// Approve a draft (human-in-the-loop)
  Future<bool> approveDraft(String draftId, {String? editedContent}) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('aiDrafts').doc(draftId).update(<String, dynamic>{
        'status': AiDraftStatus.approved.name,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (editedContent != null) 'editedContent': editedContent,
      });

      // Write audit log (required by docs/07)
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'ai.draft.approved',
        'targetId': draftId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': <String, dynamic>{
          'wasEdited': editedContent != null,
        },
      });

      await telemetryService.logEvent('ai.draft.approved', metadata: <String, dynamic>{
        'draftId': draftId,
        'wasEdited': editedContent != null,
      });

      final int index = _drafts.indexWhere((AiDraft d) => d.id == draftId);
      if (index >= 0) {
        _drafts[index] = AiDraft(
          id: _drafts[index].id,
          draftType: _drafts[index].draftType,
          status: AiDraftStatus.approved,
          content: _drafts[index].content,
          signals: _drafts[index].signals,
          confidence: _drafts[index].confidence,
          contextId: _drafts[index].contextId,
          requestedBy: _drafts[index].requestedBy,
          requestedAt: _drafts[index].requestedAt,
          reviewedBy: userId,
          reviewedAt: DateTime.now(),
          editedContent: editedContent,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AiDraftService.approveDraft error: $e');
      return false;
    }
  }

  /// Reject a draft
  Future<bool> rejectDraft(String draftId, {String? reason}) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('aiDrafts').doc(draftId).update(<String, dynamic>{
        'status': AiDraftStatus.rejected.name,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'rejectionReason': reason,
      });

      // Write audit log
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': 'ai.draft.rejected',
        'targetId': draftId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': <String, dynamic>{
          'reason': reason,
        },
      });

      await telemetryService.logEvent('ai.draft.rejected', metadata: <String, dynamic>{
        'draftId': draftId,
      });

      final int index = _drafts.indexWhere((AiDraft d) => d.id == draftId);
      if (index >= 0) {
        _drafts[index] = AiDraft(
          id: _drafts[index].id,
          draftType: _drafts[index].draftType,
          status: AiDraftStatus.rejected,
          content: _drafts[index].content,
          signals: _drafts[index].signals,
          confidence: _drafts[index].confidence,
          contextId: _drafts[index].contextId,
          requestedBy: _drafts[index].requestedBy,
          requestedAt: _drafts[index].requestedAt,
          reviewedBy: userId,
          reviewedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('AiDraftService.rejectDraft error: $e');
      return false;
    }
  }

  /// Get pending drafts that need review
  List<AiDraft> get pendingDrafts =>
      _drafts.where((AiDraft d) => d.status == AiDraftStatus.draft).toList();

  // Allowed draft types per docs/07
  static const Set<String> _allowedDraftTypes = <String>{
    'feedback',        // Teacher feedback wording
    'parent_summary',  // Weekly parent summary
    'support_strategy', // Support strategies with "why"
    'learner_commitment', // Learner commitment suggestions
  };

  AiDraftStatus _parseStatus(String? status) {
    return AiDraftStatus.values.firstWhere(
      (AiDraftStatus s) => s.name == status,
      orElse: () => AiDraftStatus.pending,
    );
  }
}

/// Status of an AI draft
enum AiDraftStatus {
  pending,   // Waiting for AI generation
  draft,     // Generated, needs review
  approved,  // Human approved
  rejected,  // Human rejected
}

/// Model for AI draft
class AiDraft {
  const AiDraft({
    required this.id,
    required this.draftType,
    required this.status,
    required this.content,
    required this.signals,
    required this.confidence,
    this.contextId,
    this.requestedBy,
    required this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.editedContent,
  });

  final String id;
  final String draftType;
  final AiDraftStatus status;
  final String content;
  final List<String> signals; // "Why" - signals used to generate
  final double confidence;    // 0.0 - 1.0 confidence score
  final String? contextId;    // Reference to the context (missionId, learnerId, etc.)
  final String? requestedBy;
  final DateTime requestedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? editedContent; // Edited version if approved with changes

  /// Get the final content (edited if available, otherwise original)
  String get finalContent => editedContent ?? content;

  /// Whether this draft needs review
  bool get needsReview => status == AiDraftStatus.draft;

  /// Confidence as percentage string
  String get confidencePercent => '${(confidence * 100).round()}%';
}
