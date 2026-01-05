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
}

class AccountabilityCycleRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityCycles');

  Future<void> upsert(AccountabilityCycleModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AccountabilityKPIRepository {
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('accountabilityKPIs');

  Future<void> upsert(AccountabilityKPIModel model) => _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
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
