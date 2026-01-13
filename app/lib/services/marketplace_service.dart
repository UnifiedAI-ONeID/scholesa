import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Marketplace service for listings, orders, and fulfillment
/// Based on docs/15_LMS_MARKETPLACE_SPEC.md
/// 
/// Lifecycle: draft → submitted → approved/rejected → published → archived
/// Purchases: checkout → webhook confirms paid → API writes Fulfillment
class MarketplaceService extends ChangeNotifier {
  MarketplaceService({
    required this.telemetryService,
    this.userId,
    this.partnerId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? partnerId;
  final FirebaseFirestore _firestore;

  List<MarketplaceListing> _listings = <MarketplaceListing>[];
  List<MarketplaceOrder> _orders = <MarketplaceOrder>[];
  List<Fulfillment> _fulfillments = <Fulfillment>[];
  bool _isLoading = false;
  String? _error;

  List<MarketplaceListing> get listings => _listings;
  List<MarketplaceOrder> get orders => _orders;
  List<Fulfillment> get fulfillments => _fulfillments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load published listings (for browsing)
  Future<void> loadPublishedListings({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('marketplaceListings')
          .where('status', isEqualTo: 'published');

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('publishedAt', descending: true).limit(50);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _listings = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return MarketplaceListing(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          description: data['description'] as String? ?? '',
          listingType: data['listingType'] as String? ?? 'mission_pack',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          currency: data['currency'] as String? ?? 'USD',
          status: data['status'] as String? ?? 'draft',
          partnerId: data['partnerId'] as String?,
          category: data['category'] as String?,
          pillar: data['pillar'] as String?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('MarketplaceService.loadPublishedListings error: $e');
    }
  }

  /// Load partner's own listings (for partner dashboard)
  Future<void> loadPartnerListings() async {
    if (partnerId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('marketplaceListings')
          .where('partnerId', isEqualTo: partnerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _listings = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return MarketplaceListing(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          description: data['description'] as String? ?? '',
          listingType: data['listingType'] as String? ?? 'mission_pack',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          currency: data['currency'] as String? ?? 'USD',
          status: data['status'] as String? ?? 'draft',
          partnerId: data['partnerId'] as String?,
          category: data['category'] as String?,
          pillar: data['pillar'] as String?,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('MarketplaceService.loadPartnerListings error: $e');
    }
  }

  /// Create a new listing (partner)
  Future<MarketplaceListing?> createListing({
    required String title,
    required String description,
    required String listingType,
    required double price,
    String currency = 'USD',
    String? category,
    String? pillar,
  }) async {
    if (partnerId == null) return null;

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('marketplaceListings').add(<String, dynamic>{
        'title': title,
        'description': description,
        'listingType': listingType,
        'price': price,
        'currency': currency,
        'status': 'draft',
        'partnerId': partnerId,
        'category': category,
        'pillar': pillar,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackListingCreated(
        listingId: docRef.id,
        listingType: listingType,
      );

      final MarketplaceListing listing = MarketplaceListing(
        id: docRef.id,
        title: title,
        description: description,
        listingType: listingType,
        price: price,
        currency: currency,
        status: 'draft',
        partnerId: partnerId,
        category: category,
        pillar: pillar,
      );

      _listings.insert(0, listing);
      notifyListeners();

      return listing;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('MarketplaceService.createListing error: $e');
      return null;
    }
  }

  /// Submit listing for approval
  Future<bool> submitForApproval(String listingId) async {
    try {
      await _firestore.collection('marketplaceListings').doc(listingId).update(<String, dynamic>{
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackListingSubmitted(listingId: listingId);

      // Update local list
      final int index = _listings.indexWhere((MarketplaceListing l) => l.id == listingId);
      if (index >= 0) {
        _listings[index] = MarketplaceListing(
          id: _listings[index].id,
          title: _listings[index].title,
          description: _listings[index].description,
          listingType: _listings[index].listingType,
          price: _listings[index].price,
          currency: _listings[index].currency,
          status: 'submitted',
          partnerId: _listings[index].partnerId,
          category: _listings[index].category,
          pillar: _listings[index].pillar,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('MarketplaceService.submitForApproval error: $e');
      return false;
    }
  }

  /// Load user's orders
  Future<void> loadOrders() async {
    if (userId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('marketplaceOrders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _orders = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return MarketplaceOrder(
          id: doc.id,
          listingId: data['listingId'] as String? ?? '',
          listingTitle: data['listingTitle'] as String? ?? '',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          status: data['status'] as String? ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('MarketplaceService.loadOrders error: $e');
    }
  }

  /// Load user's fulfillments (purchased content access)
  Future<void> loadFulfillments() async {
    if (userId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('fulfillments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _fulfillments = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Fulfillment(
          id: doc.id,
          orderId: data['orderId'] as String? ?? '',
          listingId: data['listingId'] as String? ?? '',
          listingTitle: data['listingTitle'] as String? ?? '',
          grantedAt: (data['grantedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('MarketplaceService.loadFulfillments error: $e');
    }
  }

  /// Check if user has access to a listing
  bool hasAccess(String listingId) {
    return _fulfillments.any((Fulfillment f) => 
      f.listingId == listingId && f.isActive);
  }
}

/// Model for marketplace listing
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.title,
    required this.description,
    required this.listingType,
    required this.price,
    required this.currency,
    required this.status,
    this.partnerId,
    this.category,
    this.pillar,
  });

  final String id;
  final String title;
  final String description;
  final String listingType;
  final double price;
  final String currency;
  final String status;
  final String? partnerId;
  final String? category;
  final String? pillar;

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isPublished => status == 'published';
}

/// Model for marketplace order
class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final double amount;
  final String status;
  final DateTime createdAt;

  bool get isPaid => status == 'paid';
}

/// Model for fulfillment (granted access)
class Fulfillment {
  const Fulfillment({
    required this.id,
    required this.orderId,
    required this.listingId,
    required this.listingTitle,
    required this.grantedAt,
    this.expiresAt,
  });

  final String id;
  final String orderId;
  final String listingId;
  final String listingTitle;
  final DateTime grantedAt;
  final DateTime? expiresAt;

  bool get isActive => expiresAt == null || DateTime.now().isBefore(expiresAt!);
}
