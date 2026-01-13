import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// CMS/Marketing service for public pages and lead capture
/// Based on docs/14_MARKETING_CMS_SPEC.md
/// 
/// Publishing workflow: draft → review → published → archived
/// Permissions: public pages readable by all, write is HQ-only
class CmsService extends ChangeNotifier {
  CmsService({
    required this.telemetryService,
    this.userId,
    this.userRole,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final String? userRole;
  final FirebaseFirestore _firestore;

  List<CmsPage> _pages = <CmsPage>[];
  CmsPage? _currentPage;
  bool _isLoading = false;
  String? _error;

  List<CmsPage> get pages => _pages;
  CmsPage? get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load published public pages (for public viewing)
  Future<void> loadPublishedPages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('cmsPages')
          .where('status', isEqualTo: CmsPageStatus.published.name)
          .where('audience', isEqualTo: 'public')
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      _pages = snapshot.docs.map(_parsePageDoc).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('CmsService.loadPublishedPages error: $e');
    }
  }

  /// Load all pages (for HQ editors)
  Future<void> loadAllPages() async {
    if (userRole != 'hq') {
      _error = 'Unauthorized: HQ role required';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('cmsPages')
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .get();

      _pages = snapshot.docs.map(_parsePageDoc).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('CmsService.loadAllPages error: $e');
    }
  }

  /// Load a single page by slug
  Future<CmsPage?> loadPageBySlug(String slug) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('cmsPages')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final CmsPage page = _parsePageDoc(snapshot.docs.first);

      // Check audience access
      if (page.status != CmsPageStatus.published) {
        if (userRole != 'hq') {
          return null; // Only HQ can view unpublished
        }
      }

      if (page.audience != 'public' && page.audience != userRole) {
        return null; // Audience mismatch
      }

      _currentPage = page;
      notifyListeners();

      // Track page view
      await telemetryService.trackPageViewed(pageSlug: slug);

      return page;
    } catch (e) {
      debugPrint('CmsService.loadPageBySlug error: $e');
      return null;
    }
  }

  /// Create a new CMS page (HQ only)
  Future<CmsPage?> createPage({
    required String slug,
    required String title,
    required String audience,
    Map<String, dynamic>? bodyJson,
  }) async {
    if (userRole != 'hq') {
      _error = 'Unauthorized: HQ role required';
      notifyListeners();
      return null;
    }

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('cmsPages').add(<String, dynamic>{
        'slug': slug,
        'title': title,
        'audience': audience,
        'bodyJson': bodyJson ?? <String, dynamic>{},
        'status': CmsPageStatus.draft.name,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final CmsPage page = CmsPage(
        id: docRef.id,
        slug: slug,
        title: title,
        audience: audience,
        bodyJson: bodyJson ?? <String, dynamic>{},
        status: CmsPageStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _pages.insert(0, page);
      notifyListeners();

      return page;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('CmsService.createPage error: $e');
      return null;
    }
  }

  /// Update page status (workflow transitions)
  Future<bool> updatePageStatus(String pageId, CmsPageStatus newStatus) async {
    if (userRole != 'hq') {
      _error = 'Unauthorized: HQ role required';
      notifyListeners();
      return false;
    }

    try {
      await _firestore.collection('cmsPages').doc(pageId).update(<String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == CmsPageStatus.published) 'publishedAt': FieldValue.serverTimestamp(),
      });

      final int index = _pages.indexWhere((CmsPage p) => p.id == pageId);
      if (index >= 0) {
        _pages[index] = CmsPage(
          id: _pages[index].id,
          slug: _pages[index].slug,
          title: _pages[index].title,
          audience: _pages[index].audience,
          bodyJson: _pages[index].bodyJson,
          status: newStatus,
          createdAt: _pages[index].createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('CmsService.updatePageStatus error: $e');
      return false;
    }
  }

  /// Capture a lead from form submission
  Future<bool> captureLead({
    required String email,
    required String source,
    String? name,
    String? phone,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      await _firestore.collection('leads').add(<String, dynamic>{
        'email': email,
        'name': name,
        'phone': phone,
        'source': source,
        'status': 'new',
        'customFields': customFields,
        'capturedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackLeadCaptured(source: source);

      return true;
    } catch (e) {
      debugPrint('CmsService.captureLead error: $e');
      return false;
    }
  }

  /// Get leads (HQ only)
  Future<List<Lead>> loadLeads() async {
    if (userRole != 'hq') {
      return <Lead>[];
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('leads')
          .orderBy('capturedAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Lead(
          id: doc.id,
          email: data['email'] as String? ?? '',
          name: data['name'] as String?,
          phone: data['phone'] as String?,
          source: data['source'] as String? ?? 'unknown',
          status: data['status'] as String? ?? 'new',
          capturedAt: (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('CmsService.loadLeads error: $e');
      return <Lead>[];
    }
  }

  CmsPage _parsePageDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return CmsPage(
      id: doc.id,
      slug: data['slug'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      audience: data['audience'] as String? ?? 'public',
      bodyJson: data['bodyJson'] as Map<String, dynamic>? ?? <String, dynamic>{},
      status: CmsPageStatus.values.firstWhere(
        (CmsPageStatus s) => s.name == data['status'],
        orElse: () => CmsPageStatus.draft,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Status of a CMS page
enum CmsPageStatus {
  draft,
  review,
  published,
  archived,
}

/// Model for CMS page
class CmsPage {
  const CmsPage({
    required this.id,
    required this.slug,
    required this.title,
    required this.audience,
    required this.bodyJson,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String audience; // 'public', 'learner', 'educator', 'parent', 'hq'
  final Map<String, dynamic> bodyJson;
  final CmsPageStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this page is publicly visible
  bool get isPublic => status == CmsPageStatus.published && audience == 'public';
}

/// Model for lead
class Lead {
  const Lead({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    required this.source,
    required this.status,
    required this.capturedAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String source;
  final String status;
  final DateTime capturedAt;
}
