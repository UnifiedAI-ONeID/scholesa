import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/telemetry_service.dart';

/// Scheduling service for sessions, rooms, and substitutes
/// Based on docs/44_SCHEDULING_CALENDAR_ROOMS_SPEC.md
class SchedulingService extends ChangeNotifier {
  SchedulingService({
    required this.telemetryService,
    this.siteId,
    this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? siteId;
  final String? userId;
  final FirebaseFirestore _firestore;

  List<SessionOccurrence> _occurrences = <SessionOccurrence>[];
  bool _isLoading = false;
  String? _error;

  List<SessionOccurrence> get occurrences => _occurrences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load occurrences for the active site
  Future<void> loadOccurrences({DateTime? from, DateTime? to}) async {
    if (siteId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('sessionOccurrences')
          .where('siteId', isEqualTo: siteId);

      if (from != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      query = query.orderBy('startTime', descending: false).limit(200);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _occurrences = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return SessionOccurrence(
          id: doc.id,
          sessionId: data['sessionId'] as String? ?? '',
          roomId: data['roomId'] as String? ?? '',
          educatorId: data['educatorId'] as String? ?? '',
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: (data['endTime'] as Timestamp).toDate(),
          status: data['status'] as String? ?? 'scheduled',
        );
      }).toList();

      await telemetryService.trackScheduleViewed(viewType: 'week', siteId: siteId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('SchedulingService.loadOccurrences error: $e');
    }
  }

  /// Detect room conflicts by overlapping times
  List<RoomConflict> detectConflicts() {
    final List<RoomConflict> conflicts = <RoomConflict>[];
    final Map<String, List<SessionOccurrence>> byRoom = <String, List<SessionOccurrence>>{};

    for (final SessionOccurrence occ in _occurrences) {
      byRoom.putIfAbsent(occ.roomId, () => <SessionOccurrence>[]).add(occ);
    }

    for (final MapEntry<String, List<SessionOccurrence>> entry in byRoom.entries) {
      final List<SessionOccurrence> list = entry.value..sort((SessionOccurrence a, SessionOccurrence b) => a.startTime.compareTo(b.startTime));
      for (int i = 0; i < list.length - 1; i++) {
        final SessionOccurrence current = list[i];
        final SessionOccurrence next = list[i + 1];
        if (current.endTime.isAfter(next.startTime)) {
          conflicts.add(RoomConflict(
            roomId: entry.key,
            firstOccurrenceId: current.id,
            secondOccurrenceId: next.id,
          ));
          telemetryService.trackRoomConflictDetected(
            roomId: entry.key,
            conflictType: 'double_booked',
          );
        }
      }
    }

    return conflicts;
  }

  /// Request substitute for an occurrence
  Future<bool> requestSubstitute({
    required String occurrenceId,
    required String educatorId,
  }) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('substituteRequests').add(<String, dynamic>{
        'occurrenceId': occurrenceId,
        'educatorId': educatorId,
        'requestedBy': userId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'siteId': siteId,
      });

      await telemetryService.trackSubstituteRequested(
        sessionOccurrenceId: occurrenceId,
        requestingEducatorId: educatorId,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('SchedulingService.requestSubstitute error: $e');
      return false;
    }
  }

  /// Assign substitute educator
  Future<bool> assignSubstitute({
    required String occurrenceId,
    required String substituteEducatorId,
  }) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('substituteAssignments').add(<String, dynamic>{
        'occurrenceId': occurrenceId,
        'substituteEducatorId': substituteEducatorId,
        'assignedBy': userId,
        'assignedAt': FieldValue.serverTimestamp(),
        'siteId': siteId,
      });

      await telemetryService.trackSubstituteAssigned(
        sessionOccurrenceId: occurrenceId,
        substituteEducatorId: substituteEducatorId,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('SchedulingService.assignSubstitute error: $e');
      return false;
    }
  }
}

/// Model for session occurrence
class SessionOccurrence {
  const SessionOccurrence({
    required this.id,
    required this.sessionId,
    required this.roomId,
    required this.educatorId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final String id;
  final String sessionId;
  final String roomId;
  final String educatorId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
}

/// Model for room conflicts
class RoomConflict {
  const RoomConflict({
    required this.roomId,
    required this.firstOccurrenceId,
    required this.secondOccurrenceId,
  });

  final String roomId;
  final String firstOccurrenceId;
  final String secondOccurrenceId;
}
