import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Billing service for subscriptions, invoices, and entitlements
/// Based on docs/13_PAYMENTS_BILLING_SPEC.md
/// 
/// Core rule: Only API writes subscriptions/invoices/entitlements
/// Client reads entitlements to gate features
class BillingService extends ChangeNotifier {
  BillingService({
    required this.telemetryService,
    this.userId,
    this.siteId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? siteId;
  final FirebaseFirestore _firestore;

  List<Subscription> _subscriptions = <Subscription>[];
  List<Invoice> _invoices = <Invoice>[];
  List<EntitlementGrant> _entitlements = <EntitlementGrant>[];
  bool _isLoading = false;
  String? _error;

  List<Subscription> get subscriptions => _subscriptions;
  List<Invoice> get invoices => _invoices;
  List<EntitlementGrant> get entitlements => _entitlements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if user/site has a specific entitlement
  bool hasEntitlement(String entitlementCode) {
    return _entitlements.any((EntitlementGrant e) => 
      e.code == entitlementCode && e.isActive);
  }

  /// Load subscriptions for user/site
  Future<void> loadSubscriptions() async {
    if (userId == null && siteId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('subscriptions');
      
      if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      } else if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      query = query.orderBy('createdAt', descending: true).limit(20);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _subscriptions = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Subscription(
          id: doc.id,
          planId: data['planId'] as String? ?? '',
          planName: data['planName'] as String? ?? 'Unknown Plan',
          status: data['status'] as String? ?? 'inactive',
          currentPeriodStart: (data['currentPeriodStart'] as Timestamp?)?.toDate(),
          currentPeriodEnd: (data['currentPeriodEnd'] as Timestamp?)?.toDate(),
          canceledAt: (data['canceledAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('BillingService.loadSubscriptions error: $e');
    }
  }

  /// Load invoices for user/site
  Future<void> loadInvoices() async {
    if (userId == null && siteId == null) return;

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('invoices');
      
      if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      } else if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      query = query.orderBy('createdAt', descending: true).limit(50);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _invoices = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Invoice(
          id: doc.id,
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          currency: data['currency'] as String? ?? 'USD',
          status: data['status'] as String? ?? 'pending',
          paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
          dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
          description: data['description'] as String?,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('BillingService.loadInvoices error: $e');
    }
  }

  /// Load entitlements for user/site
  Future<void> loadEntitlements() async {
    if (userId == null && siteId == null) return;

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('entitlementGrants');
      
      if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      } else if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _entitlements = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return EntitlementGrant(
          id: doc.id,
          code: data['code'] as String? ?? '',
          name: data['name'] as String? ?? '',
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('BillingService.loadEntitlements error: $e');
    }
  }

  /// Request checkout session (triggers API call, returns checkout URL)
  Future<String?> requestCheckout({
    required String productType,
    required String productId,
  }) async {
    // Track telemetry
    await telemetryService.trackCheckoutStarted(
      productType: productType,
      productId: productId,
    );

    // In production, this would call the API to create a Stripe checkout session
    // and return the checkout URL
    // For now, return null to indicate "not implemented"
    return null;
  }
}

/// Model for subscription
class Subscription {
  const Subscription({
    required this.id,
    required this.planId,
    required this.planName,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.canceledAt,
  });

  final String id;
  final String planId;
  final String planName;
  final String status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? canceledAt;

  bool get isActive => status == 'active';
  bool get isCanceled => canceledAt != null;
}

/// Model for invoice
class Invoice {
  const Invoice({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.paidAt,
    this.dueDate,
    this.description,
  });

  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final String? description;

  bool get isPaid => status == 'paid';
}

/// Model for entitlement grant
class EntitlementGrant {
  const EntitlementGrant({
    required this.id,
    required this.code,
    required this.name,
    this.expiresAt,
  });

  final String id;
  final String code;
  final String name;
  final DateTime? expiresAt;

  bool get isActive => expiresAt == null || DateTime.now().isBefore(expiresAt!);
}
