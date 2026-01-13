import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/telemetry_service.dart';
import 'partner_models.dart';

/// Service for partner operations - marketplace listings, contracts, and payouts.
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
class PartnerService extends ChangeNotifier {
  PartnerService({
    required this.partnerId,
    this.telemetryService,
  });

  final String partnerId;
  final TelemetryService? telemetryService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  List<MarketplaceListing> _listings = <MarketplaceListing>[];
  List<PartnerContract> _contracts = <PartnerContract>[];
  List<Payout> _payouts = <Payout>[];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<MarketplaceListing> get listings => _listings;
  List<PartnerContract> get contracts => _contracts;
  List<Payout> get payouts => _payouts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─────────────────────────────────────────────────────────────────────────────
  // Marketplace Listings
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load partner's marketplace listings from Firebase
  Future<void> loadListings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('marketplaceListings')
          .where('partnerId', isEqualTo: partnerId)
          .orderBy('createdAt', descending: true)
          .get();

      _listings = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return MarketplaceListing(
          id: doc.id,
          partnerId: data['partnerId'] as String? ?? partnerId,
          title: data['title'] as String? ?? 'Untitled',
          description: data['description'] as String? ?? '',
          status: ListingStatus.values.firstWhere(
            (ListingStatus s) => s.name == data['status'],
            orElse: () => ListingStatus.draft,
          ),
          category: data['category'] as String? ?? 'General',
          price: (data['price'] as num?)?.toDouble(),
          imageUrl: data['imageUrl'] as String?,
          createdAt: _parseTimestamp(data['createdAt']),
          updatedAt: _parseTimestamp(data['updatedAt']),
        );
      }).toList();

      debugPrint('Loaded ${_listings.length} listings for partner $partnerId');
    } catch (e) {
      debugPrint('Error loading listings: $e');
      _error = 'Failed to load listings: $e';
      _listings = <MarketplaceListing>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new listing
  Future<bool> createListing({
    required String title,
    required String description,
    required String category,
    double? price,
    String? imageUrl,
  }) async {
    try {
      await _firestore.collection('marketplaceListings').add(<String, dynamic>{
        'partnerId': partnerId,
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'imageUrl': imageUrl,
        'status': ListingStatus.draft.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadListings();
      return true;
    } catch (e) {
      _error = 'Failed to create listing: $e';
      notifyListeners();
      return false;
    }
  }

  /// Submit listing for approval
  Future<bool> submitListing(String listingId) async {
    try {
      await _firestore.collection('marketplaceListings').doc(listingId).update(<String, dynamic>{
        'status': ListingStatus.submitted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadListings();
      return true;
    } catch (e) {
      _error = 'Failed to submit listing: $e';
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Contracts
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load partner's contracts from Firebase
  Future<void> loadContracts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('partnerContracts')
          .where('partnerId', isEqualTo: partnerId)
          .orderBy('createdAt', descending: true)
          .get();

      _contracts = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        
        // Parse deliverables if present
        final List<PartnerDeliverable> deliverables = <PartnerDeliverable>[];
        if (data['deliverables'] is List) {
          for (final dynamic item in data['deliverables'] as List<dynamic>) {
            if (item is Map<String, dynamic>) {
              deliverables.add(PartnerDeliverable(
                id: item['id'] as String? ?? '',
                contractId: doc.id,
                title: item['title'] as String? ?? 'Untitled',
                status: DeliverableStatus.values.firstWhere(
                  (DeliverableStatus s) => s.name == item['status'],
                  orElse: () => DeliverableStatus.planned,
                ),
                dueDate: _parseTimestamp(item['dueDate']),
                submittedAt: _parseTimestamp(item['submittedAt']),
                notes: item['notes'] as String?,
              ));
            }
          }
        }

        return PartnerContract(
          id: doc.id,
          partnerId: data['partnerId'] as String? ?? partnerId,
          siteId: data['siteId'] as String? ?? '',
          title: data['title'] as String? ?? 'Untitled Contract',
          status: ContractStatus.values.firstWhere(
            (ContractStatus s) => s.name == data['status'],
            orElse: () => ContractStatus.draft,
          ),
          totalValue: (data['totalValue'] as num?)?.toDouble() ?? 0,
          startDate: _parseTimestamp(data['startDate']),
          endDate: _parseTimestamp(data['endDate']),
          deliverables: deliverables,
        );
      }).toList();

      debugPrint('Loaded ${_contracts.length} contracts for partner $partnerId');
    } catch (e) {
      debugPrint('Error loading contracts: $e');
      _error = 'Failed to load contracts: $e';
      _contracts = <PartnerContract>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit deliverable for review
  Future<bool> submitDeliverable({
    required String contractId,
    required String deliverableId,
    String? notes,
  }) async {
    try {
      // In a real implementation, this would update the specific deliverable
      // within the contract document or a subcollection
      await _firestore.collection('partnerContracts').doc(contractId).update(<String, dynamic>{
        'lastDeliverableUpdate': FieldValue.serverTimestamp(),
      });
      
      // Log the submission
      await _firestore.collection('deliverableSubmissions').add(<String, dynamic>{
        'contractId': contractId,
        'deliverableId': deliverableId,
        'partnerId': partnerId,
        'notes': notes,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Track telemetry (docs/16 - Partner deliverables)
      telemetryService?.trackDeliverableSubmitted(
        contractId: contractId,
        deliverableId: deliverableId,
      );

      await loadContracts();
      return true;
    } catch (e) {
      _error = 'Failed to submit deliverable: $e';
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Payouts
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load partner's payouts from Firebase
  Future<void> loadPayouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('payouts')
          .where('partnerId', isEqualTo: partnerId)
          .orderBy('requestedAt', descending: true)
          .get();

      _payouts = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Payout(
          id: doc.id,
          partnerId: data['partnerId'] as String? ?? partnerId,
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          status: PayoutStatus.values.firstWhere(
            (PayoutStatus s) => s.name == data['status'],
            orElse: () => PayoutStatus.pending,
          ),
          contractId: data['contractId'] as String?,
          requestedAt: _parseTimestamp(data['requestedAt']),
          paidAt: _parseTimestamp(data['paidAt']),
          notes: data['notes'] as String?,
        );
      }).toList();

      debugPrint('Loaded ${_payouts.length} payouts for partner $partnerId');
    } catch (e) {
      debugPrint('Error loading payouts: $e');
      _error = 'Failed to load payouts: $e';
      _payouts = <Payout>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request a payout
  Future<bool> requestPayout({
    required double amount,
    String? contractId,
    String? notes,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('payouts').add(<String, dynamic>{
        'partnerId': partnerId,
        'amount': amount,
        'status': PayoutStatus.pending.name,
        'contractId': contractId,
        'notes': notes,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Track telemetry (docs/16 - Partner payouts)
      telemetryService?.trackPayoutProcessed(
        payoutId: docRef.id,
        status: PayoutStatus.pending.name,
        amount: amount,
      );

      await loadPayouts();
      return true;
    } catch (e) {
      _error = 'Failed to request payout: $e';
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Get summary statistics for the partner dashboard
  Map<String, dynamic> getSummary() {
    final int activeContracts = _contracts.where(
      (PartnerContract c) => c.status == ContractStatus.active,
    ).length;
    
    final double totalEarnings = _payouts
        .where((Payout p) => p.status == PayoutStatus.paid)
        .fold(0.0, (double sum, Payout p) => sum + p.amount);
    
    final double pendingPayouts = _payouts
        .where((Payout p) => p.status == PayoutStatus.pending)
        .fold(0.0, (double sum, Payout p) => sum + p.amount);
    
    final int publishedListings = _listings.where(
      (MarketplaceListing l) => l.status == ListingStatus.published,
    ).length;

    return <String, dynamic>{
      'activeContracts': activeContracts,
      'totalEarnings': totalEarnings,
      'pendingPayouts': pendingPayouts,
      'publishedListings': publishedListings,
    };
  }
}
