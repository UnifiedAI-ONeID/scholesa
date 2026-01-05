import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.siteIds = const <String>[],
    this.activeSiteId,
    this.provisionedBy,
    this.provisionedAt,
    this.createdAt,
    this.updatedAt,
    this.archived = false,
  });

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final List<String> siteIds;
  final String? activeSiteId;
  final String? provisionedBy;
  final Timestamp? provisionedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool archived;

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'learner',
      displayName: data['displayName'] as String?,
      siteIds: List<String>.from(data['siteIds'] as List? ?? const <String>[]),
      activeSiteId: data['activeSiteId'] as String?,
      provisionedBy: data['provisionedBy'] as String?,
      provisionedAt: data['provisionedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      archived: data['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'email': email,
        'role': role,
        'displayName': displayName,
        'siteIds': siteIds,
        'activeSiteId': activeSiteId,
        'provisionedBy': provisionedBy,
        'provisionedAt': provisionedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
        'archived': archived,
      };
}

@immutable
class GuardianLinkModel {
  const GuardianLinkModel({
    required this.id,
    required this.parentId,
    required this.learnerId,
    required this.siteId,
    this.relationship,
    this.isPrimary,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String parentId;
  final String learnerId;
  final String siteId;
  final String? relationship;
  final bool? isPrimary;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory GuardianLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GuardianLinkModel(
      id: doc.id,
      parentId: data['parentId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      relationship: data['relationship'] as String?,
      isPrimary: data['isPrimary'] as bool?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'parentId': parentId,
        'learnerId': learnerId,
        'siteId': siteId,
        'relationship': relationship,
        'isPrimary': isPrimary,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class LearnerProfileModel {
  const LearnerProfileModel({
    required this.id,
    required this.learnerId,
    required this.siteId,
    this.legalName,
    this.preferredName,
    this.dateOfBirth,
    this.gradeLevel,
    this.strengths = const <String>[],
    this.learningNeeds = const <String>[],
    this.interests = const <String>[],
    this.goals = const <String>[],
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String siteId;
  final String? legalName;
  final String? preferredName;
  final String? dateOfBirth;
  final String? gradeLevel;
  final List<String> strengths;
  final List<String> learningNeeds;
  final List<String> interests;
  final List<String> goals;
  final Map<String, dynamic>? emergencyContact;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LearnerProfileModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LearnerProfileModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      gradeLevel: data['gradeLevel'] as String?,
      strengths: List<String>.from(data['strengths'] as List? ?? const <String>[]),
      learningNeeds: List<String>.from(data['learningNeeds'] as List? ?? const <String>[]),
      interests: List<String>.from(data['interests'] as List? ?? const <String>[]),
      goals: List<String>.from(data['goals'] as List? ?? const <String>[]),
      emergencyContact: data['emergencyContact'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'legalName': legalName,
        'preferredName': preferredName,
        'dateOfBirth': dateOfBirth,
        'gradeLevel': gradeLevel,
        'strengths': strengths,
        'learningNeeds': learningNeeds,
        'interests': interests,
        'goals': goals,
        'emergencyContact': emergencyContact,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ParentProfileModel {
  const ParentProfileModel({
    required this.id,
    required this.parentId,
    required this.siteId,
    this.legalName,
    this.preferredName,
    this.phone,
    this.preferredLanguage,
    this.communicationPreferences = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String parentId;
  final String siteId;
  final String? legalName;
  final String? preferredName;
  final String? phone;
  final String? preferredLanguage;
  final List<String> communicationPreferences;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ParentProfileModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ParentProfileModel(
      id: doc.id,
      parentId: data['parentId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      phone: data['phone'] as String?,
      preferredLanguage: data['preferredLanguage'] as String?,
      communicationPreferences: List<String>.from(data['communicationPreferences'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'parentId': parentId,
        'siteId': siteId,
        'legalName': legalName,
        'preferredName': preferredName,
        'phone': phone,
        'preferredLanguage': preferredLanguage,
        'communicationPreferences': communicationPreferences,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SiteModel {
  const SiteModel({
    required this.id,
    required this.name,
    this.timezone,
    this.address,
    this.adminUserIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? timezone;
  final String? address;
  final List<String> adminUserIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SiteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SiteModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      timezone: data['timezone'] as String?,
      address: data['address'] as String?,
      adminUserIds: List<String>.from(data['adminUserIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'timezone': timezone,
        'address': address,
        'adminUserIds': adminUserIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SessionModel {
  const SessionModel({
    required this.id,
    required this.siteId,
    required this.name,
    this.educatorId,
    this.pillarEmphasis = const <String>[],
    this.schedule,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String name;
  final String? educatorId;
  final List<String> pillarEmphasis;
  final Map<String, dynamic>? schedule;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SessionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SessionModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      educatorId: data['educatorId'] as String?,
      pillarEmphasis: List<String>.from(data['pillarEmphasis'] as List? ?? const <String>[]),
      schedule: data['schedule'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'name': name,
        'educatorId': educatorId,
        'pillarEmphasis': pillarEmphasis,
        'schedule': schedule,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SessionOccurrenceModel {
  const SessionOccurrenceModel({
    required this.id,
    required this.sessionId,
    required this.siteId,
    required this.date,
    required this.startAt,
    required this.endAt,
    this.educatorId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String siteId;
  final String date;
  final Timestamp startAt;
  final Timestamp endAt;
  final String? educatorId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SessionOccurrenceModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SessionOccurrenceModel(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startAt: data['startAt'] as Timestamp? ?? Timestamp.now(),
      endAt: data['endAt'] as Timestamp? ?? Timestamp.now(),
      educatorId: data['educatorId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sessionId': sessionId,
        'siteId': siteId,
        'date': date,
        'startAt': startAt,
        'endAt': endAt,
        'educatorId': educatorId,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class EnrollmentModel {
  const EnrollmentModel({
    required this.id,
    required this.siteId,
    required this.sessionId,
    required this.learnerId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionId;
  final String learnerId;
  final String? status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory EnrollmentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EnrollmentModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionId': sessionId,
        'learnerId': learnerId,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.id,
    required this.siteId,
    required this.sessionOccurrenceId,
    required this.learnerId,
    required this.status,
    required this.recordedBy,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionOccurrenceId;
  final String learnerId;
  final String status;
  final String recordedBy;
  final String? note;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AttendanceRecordModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AttendanceRecordModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String? ?? 'present',
      recordedBy: data['recordedBy'] as String? ?? '',
      note: data['note'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'learnerId': learnerId,
        'status': status,
        'recordedBy': recordedBy,
        'note': note,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PillarModel {
  const PillarModel({required this.code, required this.title, this.description, this.order});

  final String code;
  final String title;
  final String? description;
  final int? order;

  factory PillarModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PillarModel(
      code: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      order: data['order'] as int?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'description': description,
        'order': order,
      };
}

@immutable
class SkillModel {
  const SkillModel({
    required this.id,
    required this.name,
    required this.pillarCode,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String pillarCode;
  final String? description;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SkillModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SkillModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      pillarCode: data['pillarCode'] as String? ?? '',
      description: data['description'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'pillarCode': pillarCode,
        'description': description,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SkillMasteryModel {
  const SkillMasteryModel({
    required this.id,
    required this.learnerId,
    required this.skillId,
    required this.level,
    this.evidenceIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String skillId;
  final int level;
  final List<String> evidenceIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SkillMasteryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SkillMasteryModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      skillId: data['skillId'] as String? ?? '',
      level: (data['level'] as num?)?.toInt() ?? 0,
      evidenceIds: List<String>.from(data['evidenceIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'skillId': skillId,
        'level': level,
        'evidenceIds': evidenceIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pillarCodes,
    this.siteId,
    this.skillIds = const <String>[],
    this.difficulty,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final List<String> pillarCodes;
  final String? siteId;
  final List<String> skillIds;
  final String? difficulty;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      siteId: data['siteId'] as String?,
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      difficulty: data['difficulty'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'description': description,
        'pillarCodes': pillarCodes,
        'siteId': siteId,
        'skillIds': skillIds,
        'difficulty': difficulty,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionPlanModel {
  const MissionPlanModel({
    required this.id,
    required this.siteId,
    required this.sessionOccurrenceId,
    required this.educatorId,
    required this.missionIds,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionOccurrenceId;
  final String educatorId;
  final List<String> missionIds;
  final String? notes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionPlanModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionPlanModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String? ?? '',
      educatorId: data['educatorId'] as String? ?? '',
      missionIds: List<String>.from(data['missionIds'] as List? ?? const <String>[]),
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'educatorId': educatorId,
        'missionIds': missionIds,
        'notes': notes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionAttemptModel {
  const MissionAttemptModel({
    required this.id,
    required this.siteId,
    required this.missionId,
    required this.learnerId,
    required this.status,
    this.sessionOccurrenceId,
    this.reflection,
    this.artifactUrls = const <String>[],
    this.pillarCodes = const <String>[],
    this.reviewedBy,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String missionId;
  final String learnerId;
  final String status;
  final String? sessionOccurrenceId;
  final String? reflection;
  final List<String> artifactUrls;
  final List<String> pillarCodes;
  final String? reviewedBy;
  final String? reviewNotes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionAttemptModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionAttemptModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      missionId: data['missionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String?,
      reflection: data['reflection'] as String?,
      artifactUrls: List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      reviewedBy: data['reviewedBy'] as String?,
      reviewNotes: data['reviewNotes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'missionId': missionId,
        'learnerId': learnerId,
        'status': status,
        'sessionOccurrenceId': sessionOccurrenceId,
        'reflection': reflection,
        'artifactUrls': artifactUrls,
        'pillarCodes': pillarCodes,
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PortfolioModel {
  const PortfolioModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    this.title,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String? title;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PortfolioModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PortfolioModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PortfolioItemModel {
  const PortfolioItemModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.title,
    this.description,
    this.artifactUrls = const <String>[],
    this.pillarCodes = const <String>[],
    this.skillIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String title;
  final String? description;
  final List<String> artifactUrls;
  final List<String> pillarCodes;
  final List<String> skillIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PortfolioItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PortfolioItemModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      artifactUrls: List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'description': description,
        'artifactUrls': artifactUrls,
        'pillarCodes': pillarCodes,
        'skillIds': skillIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class CredentialModel {
  const CredentialModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.title,
    required this.issuedAt,
    this.pillarCodes = const <String>[],
    this.skillIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String title;
  final Timestamp issuedAt;
  final List<String> pillarCodes;
  final List<String> skillIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory CredentialModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CredentialModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      issuedAt: data['issuedAt'] as Timestamp? ?? Timestamp.now(),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'issuedAt': issuedAt,
        'pillarCodes': pillarCodes,
        'skillIds': skillIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityCycleModel {
  const AccountabilityCycleModel({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scopeType;
  final String scopeId;
  final String startDate;
  final String endDate;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityCycleModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityCycleModel(
      id: doc.id,
      scopeType: data['scopeType'] as String? ?? 'learner',
      scopeId: data['scopeId'] as String? ?? '',
      startDate: data['startDate'] as String? ?? '',
      endDate: data['endDate'] as String? ?? '',
      status: data['status'] as String? ?? 'planned',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'scopeType': scopeType,
        'scopeId': scopeId,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityKPIModel {
  const AccountabilityKPIModel({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.target,
    required this.currentValue,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String name;
  final num target;
  final num currentValue;
  final String? unit;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityKPIModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityKPIModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      target: data['target'] as num? ?? 0,
      currentValue: data['currentValue'] as num? ?? 0,
      unit: data['unit'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'name': name,
        'target': target,
        'currentValue': currentValue,
        'unit': unit,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityCommitmentModel {
  const AccountabilityCommitmentModel({
    required this.id,
    required this.cycleId,
    required this.userId,
    required this.role,
    required this.statement,
    this.pillarCodes = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String userId;
  final String role;
  final String statement;
  final List<String> pillarCodes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityCommitmentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityCommitmentModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: data['role'] as String? ?? 'learner',
      statement: data['statement'] as String? ?? '',
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'userId': userId,
        'role': role,
        'statement': statement,
        'pillarCodes': pillarCodes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityReviewModel {
  const AccountabilityReviewModel({
    required this.id,
    required this.cycleId,
    required this.reviewerId,
    required this.revieweeId,
    this.notes,
    this.rating,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String reviewerId;
  final String revieweeId;
  final String? notes;
  final int? rating;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityReviewModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityReviewModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      revieweeId: data['revieweeId'] as String? ?? '',
      notes: data['notes'] as String?,
      rating: (data['rating'] as num?)?.toInt(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'notes': notes,
        'rating': rating,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AuditLogModel {
  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.siteId,
    this.details = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String actorId;
  final String actorRole;
  final String action;
  final String entityType;
  final String entityId;
  final String? siteId;
  final Map<String, dynamic> details;
  final Timestamp? createdAt;

  factory AuditLogModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuditLogModel(
      id: doc.id,
      actorId: data['actorId'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      action: data['action'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      siteId: data['siteId'] as String?,
      details: Map<String, dynamic>.from(data['details'] as Map? ?? <String, dynamic>{}),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'actorId': actorId,
        'actorRole': actorRole,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'siteId': siteId,
        'details': details,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}
