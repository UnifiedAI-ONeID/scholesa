import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/telemetry_service.dart';

/// Curriculum service for mission versioning and rubrics
/// Based on docs/45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md
class CurriculumService extends ChangeNotifier {
  CurriculumService({
    required this.telemetryService,
    this.educatorId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? educatorId;
  final FirebaseFirestore _firestore;

  final List<MissionSnapshot> _snapshots = <MissionSnapshot>[];
  List<Rubric> _rubrics = <Rubric>[];
  bool _isLoading = false;
  String? _error;

  List<MissionSnapshot> get snapshots => _snapshots;
  List<Rubric> get rubrics => _rubrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Create a snapshot from mission template
  Future<MissionSnapshot?> createSnapshot({
    required String missionId,
    required String pillar,
    required Map<String, dynamic> content,
  }) async {
    if (educatorId == null) return null;

    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('missionSnapshots').add(<String, dynamic>{
        'missionId': missionId,
        'pillar': pillar,
        'content': content,
        'createdBy': educatorId,
        'createdAt': FieldValue.serverTimestamp(),
        'contentHash': content.hashCode.toString(),
      });

      await telemetryService.trackMissionSnapshotCreated(
        missionId: missionId,
        snapshotId: docRef.id,
        pillar: pillar,
      );

      final MissionSnapshot snapshot = MissionSnapshot(
        id: docRef.id,
        missionId: missionId,
        pillar: pillar,
        contentHash: content.hashCode.toString(),
      );

      _snapshots.insert(0, snapshot);
      notifyListeners();

      return snapshot;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('CurriculumService.createSnapshot error: $e');
      return null;
    }
  }

  /// Apply rubric to an attempt
  Future<bool> applyRubric({
    required String attemptId,
    required Rubric rubric,
    required int totalScore,
  }) async {
    if (educatorId == null) return false;

    try {
      await _firestore.collection('rubricApplications').add(<String, dynamic>{
        'attemptId': attemptId,
        'rubricId': rubric.id,
        'totalScore': totalScore,
        'appliedBy': educatorId,
        'appliedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackRubricApplied(
        attemptId: attemptId,
        rubricId: rubric.id,
        totalScore: totalScore,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('CurriculumService.applyRubric error: $e');
      return false;
    }
  }

  /// Share rubric summary to parent
  Future<bool> shareRubricToParent({
    required String attemptId,
    required Rubric rubric,
    required String learnerId,
  }) async {
    if (educatorId == null) return false;

    try {
      await _firestore.collection('parentSummaries').add(<String, dynamic>{
        'attemptId': attemptId,
        'rubricId': rubric.id,
        'learnerId': learnerId,
        'sharedBy': educatorId,
        'sharedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackRubricSharedToParent(
        attemptId: attemptId,
        rubricId: rubric.id,
        learnerId: learnerId,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('CurriculumService.shareRubricToParent error: $e');
      return false;
    }
  }

  /// Load rubrics (basic list)
  Future<void> loadRubrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('rubrics')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _rubrics = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Rubric(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          pillar: data['pillar'] as String? ?? 'pillar',
          criteriaCount: (data['criteria'] as List?)?.length ?? 0,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('CurriculumService.loadRubrics error: $e');
    }
  }
}

class MissionSnapshot {
  const MissionSnapshot({
    required this.id,
    required this.missionId,
    required this.pillar,
    required this.contentHash,
  });

  final String id;
  final String missionId;
  final String pillar;
  final String contentHash;
}

class Rubric {
  const Rubric({
    required this.id,
    required this.title,
    required this.pillar,
    required this.criteriaCount,
  });

  final String id;
  final String title;
  final String pillar;
  final int criteriaCount;
}
