import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

class UserRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('users');

  Future<UserModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<void> upsert(UserModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class LearnerProfileRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('learnerProfiles');

  Future<void> upsert(LearnerProfileModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<LearnerProfileModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(LearnerProfileModel.fromDoc).toList();
  }
}

class ParentProfileRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('parentProfiles');

  Future<void> upsert(ParentProfileModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ParentProfileModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(ParentProfileModel.fromDoc).toList();
  }
}

class GuardianLinkRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('guardianLinks');

  Future<void> upsert(GuardianLinkModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<GuardianLinkModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(GuardianLinkModel.fromDoc).toList();
  }
}

class SiteRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('sites');

  Future<List<SiteModel>> list() async {
    final snap = await _col.get();
    return snap.docs.map(SiteModel.fromDoc).toList();
  }

  Future<void> upsert(SiteModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SessionRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('sessions');

  Future<List<SessionModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(SessionModel.fromDoc).toList();
  }

  Future<void> upsert(SessionModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SessionOccurrenceRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('sessionOccurrences');

  Future<List<SessionOccurrenceModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(SessionOccurrenceModel.fromDoc).toList();
  }

  Future<void> upsert(SessionOccurrenceModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class EnrollmentRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('enrollments');

  Future<List<EnrollmentModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(EnrollmentModel.fromDoc).toList();
  }

  Future<void> upsert(EnrollmentModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AttendanceRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('attendanceRecords');

  String deterministicId(String sessionOccurrenceId, String learnerId) => '${sessionOccurrenceId}_$learnerId';

  Future<void> upsert(AttendanceRecordModel model) {
    final id = model.id.isNotEmpty ? model.id : deterministicId(model.sessionOccurrenceId, model.learnerId);
    return _col.doc(id).set(model.toMap(), SetOptions(merge: true));
  }

  Future<List<AttendanceRecordModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(AttendanceRecordModel.fromDoc).toList();
  }

  Future<List<AttendanceRecordModel>> listRecentBySite(String siteId, {int limit = 10}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AttendanceRecordModel.fromDoc).toList();
  }
}

class PillarRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('pillars');

  Future<List<PillarModel>> list() async {
    final snap = await _col.get();
    return snap.docs.map(PillarModel.fromDoc).toList();
  }

  Future<void> upsert(PillarModel model) => _col.doc(model.code).set(model.toMap(), SetOptions(merge: true));
}

class SkillRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('skills');

  Future<List<SkillModel>> listByPillar(String pillarCode) async {
    final snap = await _col.where('pillarCode', isEqualTo: pillarCode).get();
    return snap.docs.map(SkillModel.fromDoc).toList();
  }

  Future<void> upsert(SkillModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SkillMasteryRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('skillMastery');

  Future<List<SkillMasteryModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(SkillMasteryModel.fromDoc).toList();
  }

  Future<void> upsert(SkillMasteryModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('missions');

  Future<List<MissionModel>> listBySiteOrGlobal(String siteId) async {
    final snap = await _col.where('siteId', whereIn: <String?>[siteId, null]).get();
    return snap.docs.map(MissionModel.fromDoc).toList();
  }

  Future<void> upsert(MissionModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionPlanRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('missionPlans');

  Future<void> upsert(MissionPlanModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionAttemptRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('missionAttempts');

  Future<void> upsert(MissionAttemptModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MissionAttemptModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(MissionAttemptModel.fromDoc).toList();
  }
}

class PortfolioRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('portfolios');

  Future<void> upsert(PortfolioModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class PortfolioItemRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('portfolioItems');

  Future<void> upsert(PortfolioItemModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<PortfolioItemModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(PortfolioItemModel.fromDoc).toList();
  }
}

class CredentialRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('credentials');

  Future<void> upsert(CredentialModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<CredentialModel>> listByLearner(String learnerId, {String? siteId, int limit = 10}) async {
    Query<Map<String, dynamic>> query = _col.where('learnerId', isEqualTo: learnerId).orderBy('issuedAt', descending: true).limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    return snap.docs.map(CredentialModel.fromDoc).toList();
  }
}

class AccountabilityCycleRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityCycles');

  Future<void> upsert(AccountabilityCycleModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AccountabilityKPIRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityKPIs');

  Future<void> upsert(AccountabilityKPIModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<AccountabilityKPIModel>> listRecent({int limit = 6}) async {
    final snap = await _col.orderBy('updatedAt', descending: true).limit(limit).get();
    return snap.docs.map(AccountabilityKPIModel.fromDoc).toList();
  }
}

class AccountabilityCommitmentRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityCommitments');

  Future<void> upsert(AccountabilityCommitmentModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AccountabilityReviewRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityReviews');

  Future<void> upsert(AccountabilityReviewModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AuditLogRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('auditLogs');

  Future<void> log(AuditLogModel model) => _col.doc(model.id).set(model.toMap());
}

class AnnouncementRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('announcements');

  Future<List<AnnouncementModel>> listBySiteAndRole({required String siteId, required String role}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('roles', arrayContains: role)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return snap.docs.map(AnnouncementModel.fromDoc).toList();
  }
}

class CmsRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('cmsPages');

  Future<CmsPageModel?> fetchPublishedBySlug({required String slug, String? role}) async {
    final docRef = _col.doc(slug);
    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await docRef.get(const GetOptions(source: Source.cache));
      if (!doc.exists) {
        doc = null;
      }
    } catch (_) {
      doc = null;
    }

    if (doc == null) {
      try {
        doc = await docRef.get();
      } catch (_) {
        return null;
      }
    }
    if (!doc.exists) return null;
    final model = CmsPageModel.fromDoc(doc);
    if (model.status != 'published') return null;
    final audience = model.audience.toLowerCase();
    final normalizedRole = role?.toLowerCase();
    final audienceAllowsAll = audience == 'public' || audience == 'any' || audience == 'all';
    final audienceMatchesRole = normalizedRole != null && normalizedRole.isNotEmpty && audience == normalizedRole;
    if (!audienceAllowsAll && !audienceMatchesRole) return null;
    return model;
  }
}

class MessageThreadRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('messageThreads');

  Future<void> upsert(MessageThreadModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MessageThreadModel>> listByParticipant({required String userId, String? siteId, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _col.where('participantIds', arrayContains: userId).orderBy('createdAt', descending: true).limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    return snap.docs.map(MessageThreadModel.fromDoc).toList();
  }
}

class MessageRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('messages');

  Future<void> add(MessageModel model) => _col.doc(model.id).set(model.toMap());

  Future<List<MessageModel>> listByThread(String threadId, {int limit = 50}) async {
    final snap = await _col.where('threadId', isEqualTo: threadId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(MessageModel.fromDoc).toList();
  }
}

class LeadRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('leads');

  Future<void> createLead({
    required String name,
    required String email,
    required String source,
    String status = 'new',
    String? message,
    String? siteId,
    String? slug,
  }) async {
    final doc = _col.doc();
    final model = LeadModel(
      id: doc.id,
      name: name,
      email: email,
      source: source,
      status: status,
      message: message,
      siteId: siteId,
      slug: slug,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
  }
}

class OrderRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('orders');

  Future<String> createPaidOrder({
    required String siteId,
    required String userId,
    required String productId,
    required String amount,
    required String currency,
    List<String> entitlementRoles = const <String>[],
  }) async {
    final doc = _col.doc();
    final model = OrderModel(
      id: doc.id,
      siteId: siteId,
      userId: userId,
      productId: productId,
      amount: amount,
      currency: currency,
      entitlementRoles: entitlementRoles,
      status: 'paid',
      createdAt: Timestamp.now(),
      paidAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<OrderModel>> listByUser({required String userId, String? siteId, int limit = 20}) async {
    Query<Map<String, dynamic>> q = _col.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      q = q.where('siteId', isEqualTo: siteId);
    }
    final snap = await q.get();
    return snap.docs.map(OrderModel.fromDoc).toList();
  }
}

class EntitlementRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('entitlements');

  Future<void> grant({
    required String userId,
    required String siteId,
    required String productId,
    List<String> roles = const <String>[],
    Timestamp? expiresAt,
  }) async {
    final doc = _col.doc();
    final model = EntitlementModel(
      id: doc.id,
      userId: userId,
      siteId: siteId,
      productId: productId,
      roles: roles,
      expiresAt: expiresAt,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());

    // Attach entitlements to the user profile for quick lookup.
    await FirebaseFirestore.instance.collection('users').doc(userId).set(
      <String, dynamic>{
        'roles': FieldValue.arrayUnion(roles),
        'entitlements': FieldValue.arrayUnion(roles),
        'siteIds': FieldValue.arrayUnion(<String>[siteId]),
        'primarySiteId': siteId,
      },
      SetOptions(merge: true),
    );
  }
}

class PartnerOrgRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('partnerOrgs');

  Future<String> create({required String name, required String ownerId, String? contactEmail}) async {
    final doc = _col.doc();
    final model = PartnerOrgModel(
      id: doc.id,
      name: name,
      ownerId: ownerId,
      contactEmail: contactEmail,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<PartnerOrgModel>> listMine(String ownerId) async {
    final snap = await _col.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).limit(10).get();
    return snap.docs.map(PartnerOrgModel.fromDoc).toList();
  }

  Future<List<PartnerOrgModel>> listAll({int limit = 20}) async {
    final snap = await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerOrgModel.fromDoc).toList();
  }
}

class PartnerContractRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('partnerContracts');

  Future<String> createDraft({
    required String partnerOrgId,
    required String title,
    required String amount,
    required String currency,
    String? createdBy,
    Timestamp? dueDate,
  }) async {
    final doc = _col.doc();
    final model = PartnerContractModel(
      id: doc.id,
      partnerOrgId: partnerOrgId,
      title: title,
      amount: amount,
      currency: currency,
      status: 'draft',
      createdBy: createdBy,
      dueDate: dueDate,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> approve({required String id, required String approvedBy}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<List<PartnerContractModel>> listByOrg(String partnerOrgId, {int limit = 20}) async {
    final snap = await _col.where('partnerOrgId', isEqualTo: partnerOrgId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerContractModel.fromDoc).toList();
  }

  Future<List<PartnerContractModel>> listPendingApproval({int limit = 20}) async {
    final snap = await _col.where('status', isEqualTo: 'draft').orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerContractModel.fromDoc).toList();
  }
}

class PartnerDeliverableRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('partnerDeliverables');

  Future<String> submit({
    required String contractId,
    required String title,
    String? description,
    String? evidenceUrl,
    String? submittedBy,
  }) async {
    final doc = _col.doc();
    final model = PartnerDeliverableModel(
      id: doc.id,
      contractId: contractId,
      title: title,
      description: description,
      evidenceUrl: evidenceUrl,
      status: 'submitted',
      submittedBy: submittedBy,
      submittedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> accept({required String id, required String acceptedBy}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'accepted',
      'acceptedBy': acceptedBy,
      'acceptedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<List<PartnerDeliverableModel>> listByContract(String contractId, {int limit = 20}) async {
    final snap = await _col.where('contractId', isEqualTo: contractId).orderBy('submittedAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerDeliverableModel.fromDoc).toList();
  }

  Future<List<PartnerDeliverableModel>> listPendingAcceptance({int limit = 20}) async {
    final snap = await _col.where('status', isEqualTo: 'submitted').orderBy('submittedAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerDeliverableModel.fromDoc).toList();
  }
}

class PayoutRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('payouts');

  Future<String> createPending({
    required String contractId,
    required String amount,
    required String currency,
    String? createdBy,
  }) async {
    final doc = _col.doc();
    final model = PayoutModel(
      id: doc.id,
      contractId: contractId,
      amount: amount,
      currency: currency,
      status: 'pending',
      createdBy: createdBy,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> approve({required String id, required String approvedBy}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<List<PayoutModel>> listByContract(String contractId, {int limit = 20}) async {
    final snap = await _col.where('contractId', isEqualTo: contractId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PayoutModel.fromDoc).toList();
  }

  Future<List<PayoutModel>> listPendingApproval({int limit = 20}) async {
    final snap = await _col.where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PayoutModel.fromDoc).toList();
  }
}

class AiDraftRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('aiDrafts');

  Future<String> createRequest({
    required String requesterId,
    required String siteId,
    required String title,
    required String prompt,
  }) async {
    final doc = _col.doc();
    final model = AiDraftModel(
      id: doc.id,
      requesterId: requesterId,
      siteId: siteId,
      title: title,
      prompt: prompt,
      status: 'requested',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> review({
    required String id,
    required String reviewerId,
    required String status,
    String? notes,
  }) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': status,
      'reviewerId': reviewerId,
      'reviewNotes': notes,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<List<AiDraftModel>> listMine(String requesterId, {int limit = 20}) async {
    final snap = await _col.where('requesterId', isEqualTo: requesterId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(AiDraftModel.fromDoc).toList();
  }

  Future<List<AiDraftModel>> listPending({int limit = 20}) async {
    final snap = await _col.where('status', isEqualTo: 'requested').orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(AiDraftModel.fromDoc).toList();
  }
}
