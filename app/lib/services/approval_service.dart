import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Approval service for HQ approvals queue
/// Based on docs/15_LMS_MARKETPLACE_SPEC.md and docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
/// 
/// HQ approves:
/// - Marketplace listings (submitted → approved/rejected → published)
/// - Partner contracts (submitted → negotiation → approved)
/// - Payouts (pending → approved → paid)
class ApprovalService extends ChangeNotifier {
  ApprovalService({
    required this.telemetryService,
    this.userId,
    this.userRole,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? userRole;
  final FirebaseFirestore _firestore;

  List<ApprovalItem> _pendingListings = <ApprovalItem>[];
  List<ApprovalItem> _pendingContracts = <ApprovalItem>[];
  List<ApprovalItem> _pendingPayouts = <ApprovalItem>[];
  bool _isLoading = false;
  String? _error;

  List<ApprovalItem> get pendingListings => _pendingListings;
  List<ApprovalItem> get pendingContracts => _pendingContracts;
  List<ApprovalItem> get pendingPayouts => _pendingPayouts;
  List<ApprovalItem> get allPending => <ApprovalItem>[..._pendingListings, ..._pendingContracts, ..._pendingPayouts];
  int get totalPendingCount => _pendingListings.length + _pendingContracts.length + _pendingPayouts.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all pending approvals (HQ only)
  Future<void> loadAllPending() async {
    if (userRole != 'hq') {
      _error = 'Unauthorized: HQ role required';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait(<Future<void>>[
        _loadPendingListings(),
        _loadPendingContracts(),
        _loadPendingPayouts(),
      ]);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('ApprovalService.loadAllPending error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPendingListings() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('marketplaceListings')
        .where('status', isEqualTo: 'submitted')
        .orderBy('createdAt', descending: false)
        .limit(50)
        .get();

    _pendingListings = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return ApprovalItem(
        id: doc.id,
        type: ApprovalType.listing,
        title: data['title'] as String? ?? 'Untitled Listing',
        description: data['description'] as String?,
        partnerId: data['partnerId'] as String?,
        submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        metadata: <String, dynamic>{
          'category': data['category'],
          'price': data['price'],
        },
      );
    }).toList();
  }

  /// Approve a listing
  Future<bool> approveListing(String listingId) async {
    return _updateListingStatus(listingId, 'approved');
  }

  /// Reject a listing
  Future<bool> rejectListing(String listingId, {String? reason}) async {
    return _updateListingStatus(listingId, 'rejected', reason: reason);
  }

  Future<bool> _updateListingStatus(String listingId, String newStatus, {String? reason}) async {
    if (userRole != 'hq') return false;

    try {
      await _firestore.collection('marketplaceListings').doc(listingId).update(<String, dynamic>{
        'status': newStatus,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'reviewNotes': reason,
      });

      // Write audit log
      await _writeAuditLog(
        action: 'listing.$newStatus',
        targetId: listingId,
        targetType: 'marketplace_listing',
        metadata: <String, dynamic>{'reason': reason},
      );

      await telemetryService.trackListingStatusChanged(
        listingId: listingId,
        fromStatus: 'submitted',
        toStatus: newStatus,
      );

      _pendingListings.removeWhere((ApprovalItem i) => i.id == listingId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('ApprovalService._updateListingStatus error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTRACTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPendingContracts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('partnerContracts')
        .where('status', isEqualTo: 'submitted')
        .orderBy('createdAt', descending: false)
        .limit(50)
        .get();

    _pendingContracts = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return ApprovalItem(
        id: doc.id,
        type: ApprovalType.contract,
        title: data['title'] as String? ?? 'Untitled Contract',
        description: data['scope'] as String?,
        partnerId: data['partnerId'] as String?,
        submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        metadata: <String, dynamic>{
          'totalValue': data['totalValue'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        },
      );
    }).toList();
  }

  /// Approve a contract
  Future<bool> approveContract(String contractId) async {
    return _updateContractStatus(contractId, 'approved');
  }

  /// Reject a contract
  Future<bool> rejectContract(String contractId, {String? reason}) async {
    return _updateContractStatus(contractId, 'rejected', reason: reason);
  }

  /// Move contract to negotiation
  Future<bool> negotiateContract(String contractId, {String? notes}) async {
    return _updateContractStatus(contractId, 'negotiation', reason: notes);
  }

  Future<bool> _updateContractStatus(String contractId, String newStatus, {String? reason}) async {
    if (userRole != 'hq') return false;

    try {
      await _firestore.collection('partnerContracts').doc(contractId).update(<String, dynamic>{
        'status': newStatus,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'reviewNotes': reason,
      });

      await _writeAuditLog(
        action: 'contract.$newStatus',
        targetId: contractId,
        targetType: 'partner_contract',
        metadata: <String, dynamic>{'reason': reason},
      );

      await telemetryService.trackContractStatusChange(
        contractId: contractId,
        fromStatus: 'submitted',
        toStatus: newStatus,
      );

      _pendingContracts.removeWhere((ApprovalItem i) => i.id == contractId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('ApprovalService._updateContractStatus error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYOUTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPendingPayouts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('payouts')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: false)
        .limit(50)
        .get();

    _pendingPayouts = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return ApprovalItem(
        id: doc.id,
        type: ApprovalType.payout,
        title: 'Payout Request',
        description: 'Amount: \$${data['amount']?.toString() ?? '0'}',
        partnerId: data['partnerId'] as String?,
        submittedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        metadata: <String, dynamic>{
          'amount': data['amount'],
          'contractId': data['contractId'],
        },
      );
    }).toList();
  }

  /// Approve a payout
  Future<bool> approvePayout(String payoutId) async {
    return _updatePayoutStatus(payoutId, 'approved');
  }

  /// Reject a payout
  Future<bool> rejectPayout(String payoutId, {String? reason}) async {
    return _updatePayoutStatus(payoutId, 'failed', reason: reason);
  }

  Future<bool> _updatePayoutStatus(String payoutId, String newStatus, {String? reason}) async {
    if (userRole != 'hq') return false;

    try {
      final ApprovalItem? item = _pendingPayouts.where((ApprovalItem i) => i.id == payoutId).firstOrNull;
      final double amount = (item?.metadata?['amount'] as num?)?.toDouble() ?? 0;

      await _firestore.collection('payouts').doc(payoutId).update(<String, dynamic>{
        'status': newStatus,
        'approvedBy': userId,
        'approvedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'notes': reason,
      });

      await _writeAuditLog(
        action: 'payout.$newStatus',
        targetId: payoutId,
        targetType: 'payout',
        metadata: <String, dynamic>{
          'amount': amount,
          'reason': reason,
        },
      );

      await telemetryService.trackPayoutProcessed(
        payoutId: payoutId,
        status: newStatus,
        amount: amount,
      );

      _pendingPayouts.removeWhere((ApprovalItem i) => i.id == payoutId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('ApprovalService._updatePayoutStatus error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _writeAuditLog({
    required String action,
    required String targetId,
    required String targetType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': action,
        'targetId': targetId,
        'targetType': targetType,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('ApprovalService._writeAuditLog error: $e');
    }
  }
}

/// Type of approval item
enum ApprovalType {
  listing,
  contract,
  payout,
}

/// Model for approval item
class ApprovalItem {
  const ApprovalItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.partnerId,
    required this.submittedAt,
    this.metadata,
  });

  final String id;
  final ApprovalType type;
  final String title;
  final String? description;
  final String? partnerId;
  final DateTime submittedAt;
  final Map<String, dynamic>? metadata;

  String get typeLabel {
    switch (type) {
      case ApprovalType.listing:
        return 'Listing';
      case ApprovalType.contract:
        return 'Contract';
      case ApprovalType.payout:
        return 'Payout';
    }
  }

  Duration get waitTime => DateTime.now().difference(submittedAt);
}
