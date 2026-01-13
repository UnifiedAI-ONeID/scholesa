import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Portfolio service for learner portfolios and credentials
/// Based on docs/47_ROLE_DASHBOARD_CARD_REGISTRY.md (learner_portfolio card)
class PortfolioService extends ChangeNotifier {
  PortfolioService({
    required this.telemetryService,
    this.learnerId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? learnerId;
  final FirebaseFirestore _firestore;

  List<PortfolioItem> _items = <PortfolioItem>[];
  List<Credential> _credentials = <Credential>[];
  bool _isLoading = false;
  String? _error;

  List<PortfolioItem> get items => _items;
  List<Credential> get credentials => _credentials;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get items visible to parents (parent-safe)
  List<PortfolioItem> get parentVisibleItems => 
      _items.where((PortfolioItem i) => i.isParentVisible).toList();

  /// Load portfolio items for learner
  Future<void> loadItems() async {
    if (learnerId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('portfolioItems')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _items = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return PortfolioItem(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          description: data['description'] as String?,
          itemType: data['itemType'] as String? ?? 'artifact',
          pillar: data['pillar'] as String?,
          missionId: data['missionId'] as String?,
          artifactUrl: data['artifactUrl'] as String?,
          thumbnailUrl: data['thumbnailUrl'] as String?,
          isHighlight: data['isHighlight'] as bool? ?? false,
          isParentVisible: data['isParentVisible'] as bool? ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('PortfolioService.loadItems error: $e');
    }
  }

  /// Load credentials for learner
  Future<void> loadCredentials() async {
    if (learnerId == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('credentials')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('issuedAt', descending: true)
          .limit(50)
          .get();

      _credentials = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Credential(
          id: doc.id,
          title: data['title'] as String? ?? '',
          credentialType: data['credentialType'] as String? ?? 'badge',
          pillar: data['pillar'] as String?,
          issuer: data['issuer'] as String?,
          issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
          imageUrl: data['imageUrl'] as String?,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('PortfolioService.loadCredentials error: $e');
    }
  }

  /// Add portfolio item
  Future<PortfolioItem?> addItem({
    required String title,
    required String itemType,
    String? description,
    String? pillar,
    String? missionId,
    String? artifactUrl,
    bool isHighlight = false,
    bool isParentVisible = false,
  }) async {
    if (learnerId == null) return null;

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('portfolioItems').add(<String, dynamic>{
        'learnerId': learnerId,
        'title': title,
        'description': description,
        'itemType': itemType,
        'pillar': pillar,
        'missionId': missionId,
        'artifactUrl': artifactUrl,
        'isHighlight': isHighlight,
        'isParentVisible': isParentVisible,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackPortfolioItemAdded(
        itemId: docRef.id,
        itemType: itemType,
        pillar: pillar ?? 'none',
      );

      final PortfolioItem item = PortfolioItem(
        id: docRef.id,
        title: title,
        description: description,
        itemType: itemType,
        pillar: pillar,
        missionId: missionId,
        artifactUrl: artifactUrl,
        isHighlight: isHighlight,
        isParentVisible: isParentVisible,
        createdAt: DateTime.now(),
      );

      _items.insert(0, item);
      notifyListeners();

      return item;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('PortfolioService.addItem error: $e');
      return null;
    }
  }

  /// Toggle item highlight
  Future<bool> toggleHighlight(String itemId) async {
    try {
      final int index = _items.indexWhere((PortfolioItem i) => i.id == itemId);
      if (index < 0) return false;

      final bool newValue = !_items[index].isHighlight;

      await _firestore.collection('portfolioItems').doc(itemId).update(<String, dynamic>{
        'isHighlight': newValue,
      });

      _items[index] = PortfolioItem(
        id: _items[index].id,
        title: _items[index].title,
        description: _items[index].description,
        itemType: _items[index].itemType,
        pillar: _items[index].pillar,
        missionId: _items[index].missionId,
        artifactUrl: _items[index].artifactUrl,
        thumbnailUrl: _items[index].thumbnailUrl,
        isHighlight: newValue,
        isParentVisible: _items[index].isParentVisible,
        createdAt: _items[index].createdAt,
      );
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('PortfolioService.toggleHighlight error: $e');
      return false;
    }
  }

  /// Share item with parent
  Future<bool> shareWithParent(String itemId) async {
    try {
      await _firestore.collection('portfolioItems').doc(itemId).update(<String, dynamic>{
        'isParentVisible': true,
        'sharedWithParentAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackPortfolioItemShared(
        itemId: itemId,
        shareTarget: 'parent',
      );

      final int index = _items.indexWhere((PortfolioItem i) => i.id == itemId);
      if (index >= 0) {
        _items[index] = PortfolioItem(
          id: _items[index].id,
          title: _items[index].title,
          description: _items[index].description,
          itemType: _items[index].itemType,
          pillar: _items[index].pillar,
          missionId: _items[index].missionId,
          artifactUrl: _items[index].artifactUrl,
          thumbnailUrl: _items[index].thumbnailUrl,
          isHighlight: _items[index].isHighlight,
          isParentVisible: true,
          createdAt: _items[index].createdAt,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('PortfolioService.shareWithParent error: $e');
      return false;
    }
  }
}

/// Model for portfolio item
class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.title,
    this.description,
    required this.itemType,
    this.pillar,
    this.missionId,
    this.artifactUrl,
    this.thumbnailUrl,
    required this.isHighlight,
    required this.isParentVisible,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String itemType;
  final String? pillar;
  final String? missionId;
  final String? artifactUrl;
  final String? thumbnailUrl;
  final bool isHighlight;
  final bool isParentVisible;
  final DateTime createdAt;
}

/// Model for credential
class Credential {
  const Credential({
    required this.id,
    required this.title,
    required this.credentialType,
    this.pillar,
    this.issuer,
    required this.issuedAt,
    this.expiresAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String credentialType;
  final String? pillar;
  final String? issuer;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String? imageUrl;

  bool get isValid => expiresAt == null || DateTime.now().isBefore(expiresAt!);
}
