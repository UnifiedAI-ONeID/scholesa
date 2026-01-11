import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'habit_models.dart';

/// Service for habit tracking and coaching - LIVE DATA FROM FIREBASE
class HabitService extends ChangeNotifier {

  HabitService({
    this.learnerId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final String? learnerId;

  List<Habit> _habits = <Habit>[];
  List<HabitLog> _recentLogs = <HabitLog>[];
  WeeklyHabitSummary? _weeklySummary;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Habit> get habits => _habits;
  List<Habit> get activeHabits => _habits.where((Habit h) => h.isActive).toList();
  List<Habit> get todayHabits => activeHabits; // Could filter by frequency/day
  List<HabitLog> get recentLogs => _recentLogs;
  WeeklyHabitSummary? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get completedTodayCount => _habits.where((Habit h) => h.isCompletedToday).length;
  int get totalTodayCount => todayHabits.length;
  double get todayProgress => totalTodayCount > 0 ? completedTodayCount / totalTodayCount : 0;

  int get totalStreak {
    if (_habits.isEmpty) return 0;
    return _habits.fold(0, (int sum, Habit h) => sum + h.currentStreak);
  }

  /// Load all habits from Firebase
  Future<void> loadHabits() async {
    if (learnerId == null) {
      _error = 'Not logged in. Please log in to view habits.';
      notifyListeners();
      return;
    }
    final String currentLearnerId = learnerId!;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load habits from Firebase
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot = await _firestore
          .collection('habits')
          .where('learnerId', isEqualTo: currentLearnerId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _habits = habitsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return _parseHabit(doc);
      }).toList();

      // Load recent logs
      final QuerySnapshot<Map<String, dynamic>> logsSnapshot = await _firestore
          .collection('habit_logs')
          .where('learnerId', isEqualTo: currentLearnerId)
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();
      
      _recentLogs = logsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return _parseHabitLog(doc);
      }).toList();

      // Calculate weekly summary
      _weeklySummary = _calculateWeeklySummary();
    } catch (e) {
      _error = 'Failed to load habits: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Habit _parseHabit(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return Habit(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      emoji: data['emoji'] as String? ?? '📝',
      category: _parseCategory(data['category'] as String?),
      frequency: _parseFrequency(data['frequency'] as String?),
      preferredTime: _parseTimePreference(data['preferredTime'] as String?),
      targetMinutes: (data['targetMinutes'] as int?) ?? 10,
      currentStreak: (data['currentStreak'] as int?) ?? 0,
      longestStreak: (data['longestStreak'] as int?) ?? 0,
      totalCompletions: (data['totalCompletions'] as int?) ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastCompletedAt: (data['lastCompletedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  HabitLog _parseHabitLog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return HabitLog(
      id: doc.id,
      habitId: data['habitId'] as String? ?? '',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as int?) ?? 0,
      note: data['note'] as String?,
      moodEmoji: data['moodEmoji'] as String?,
    );
  }

  HabitCategory _parseCategory(String? category) {
    switch (category) {
      case 'learning': return HabitCategory.learning;
      case 'health': return HabitCategory.health;
      case 'mindfulness': return HabitCategory.mindfulness;
      case 'social': return HabitCategory.social;
      case 'creativity': return HabitCategory.creativity;
      case 'productivity': return HabitCategory.productivity;
      default: return HabitCategory.learning;
    }
  }

  HabitFrequency _parseFrequency(String? frequency) {
    switch (frequency) {
      case 'daily': return HabitFrequency.daily;
      case 'weekdays': return HabitFrequency.weekdays;
      case 'weekends': return HabitFrequency.weekends;
      case 'weekly': return HabitFrequency.weekly;
      case 'custom': return HabitFrequency.custom;
      default: return HabitFrequency.daily;
    }
  }

  HabitTimePreference _parseTimePreference(String? time) {
    switch (time) {
      case 'morning': return HabitTimePreference.morning;
      case 'afternoon': return HabitTimePreference.afternoon;
      case 'evening': return HabitTimePreference.evening;
      default: return HabitTimePreference.anytime;
    }
  }

  WeeklyHabitSummary _calculateWeeklySummary() {
    final DateTime now = DateTime.now();
    final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    final DateTime weekStartMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    final List<HabitLog> weekLogs = _recentLogs.where((HabitLog log) {
      return log.completedAt.isAfter(weekStartMidnight);
    }).toList();

    final Map<String, int> completionsByHabit = <String, int>{};
    int totalMinutes = 0;
    
    for (final HabitLog log in weekLogs) {
      completionsByHabit[log.habitId] = (completionsByHabit[log.habitId] ?? 0) + 1;
      totalMinutes += log.durationMinutes;
    }

    // Calculate daily completions (Mon-Sun)
    final List<bool> dailyCompletions = List<bool>.generate(7, (int i) {
      final DateTime day = weekStartMidnight.add(Duration(days: i));
      return weekLogs.any((HabitLog log) {
        final DateTime logDate = DateTime(log.completedAt.year, log.completedAt.month, log.completedAt.day);
        return logDate == day;
      });
    });

    return WeeklyHabitSummary(
      weekStart: weekStartMidnight,
      totalCompletions: weekLogs.length,
      totalMinutes: totalMinutes,
      completionsByHabit: completionsByHabit,
      dailyCompletions: dailyCompletions,
    );
  }

  /// Create a new habit and save to Firebase
  Future<Habit?> createHabit({
    required String title,
    String? description,
    required String emoji,
    required HabitCategory category,
    HabitFrequency frequency = HabitFrequency.daily,
    HabitTimePreference preferredTime = HabitTimePreference.anytime,
    int targetMinutes = 10,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore
          .collection('habits')
          .add(<String, dynamic>{
        'learnerId': learnerId,
        'title': title,
        'description': description,
        'emoji': emoji,
        'category': category.name,
        'frequency': frequency.name,
        'preferredTime': preferredTime.name,
        'targetMinutes': targetMinutes,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalCompletions': 0,
        'createdAt': Timestamp.fromDate(now),
        'isActive': true,
      });

      final Habit habit = Habit(
        id: docRef.id,
        title: title,
        description: description,
        emoji: emoji,
        category: category,
        frequency: frequency,
        preferredTime: preferredTime,
        targetMinutes: targetMinutes,
        createdAt: now,
      );

      _habits = <Habit>[..._habits, habit];
      notifyListeners();
      return habit;
    } catch (e) {
      _error = 'Failed to create habit: $e';
      notifyListeners();
      return null;
    }
  }

  /// Complete a habit for today and save to Firebase
  Future<bool> completeHabit(String habitId, {int? durationMinutes, String? note, String? moodEmoji}) async {
    try {
      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index == -1) return false;

      final Habit habit = _habits[index];
      final DateTime now = DateTime.now();
      
      // Save log to Firebase
      final DocumentReference<Map<String, dynamic>> logRef = await _firestore
          .collection('habit_logs')
          .add(<String, dynamic>{
        'habitId': habitId,
        'learnerId': learnerId,
        'completedAt': Timestamp.fromDate(now),
        'durationMinutes': durationMinutes ?? habit.targetMinutes,
        'note': note,
        'moodEmoji': moodEmoji,
      });

      // Create local log entry
      final HabitLog log = HabitLog(
        id: logRef.id,
        habitId: habitId,
        completedAt: now,
        durationMinutes: durationMinutes ?? habit.targetMinutes,
        note: note,
        moodEmoji: moodEmoji,
      );
      _recentLogs = <HabitLog>[log, ..._recentLogs];

      // Calculate new streak
      final int newStreak = _calculateNewStreak(habit);
      final int newLongestStreak = newStreak > habit.longestStreak ? newStreak : habit.longestStreak;
      final int newTotalCompletions = habit.totalCompletions + 1;

      // Update habit in Firebase
      await _firestore.collection('habits').doc(habitId).update(<String, dynamic>{
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'totalCompletions': newTotalCompletions,
        'lastCompletedAt': Timestamp.fromDate(now),
      });

      // Update local state
      _habits[index] = habit.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
        totalCompletions: newTotalCompletions,
        lastCompletedAt: now,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to complete habit: $e';
      notifyListeners();
      return false;
    }
  }

  int _calculateNewStreak(Habit habit) {
    if (habit.lastCompletedAt == null) return 1;
    
    final DateTime now = DateTime.now();
    final DateTime lastDate = habit.lastCompletedAt!;
    final int dayDiff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;

    if (dayDiff == 0) return habit.currentStreak; // Already completed today
    if (dayDiff == 1) return habit.currentStreak + 1; // Consecutive day
    return 1; // Streak broken
  }

  /// Update habit settings in Firebase
  Future<bool> updateHabit(String habitId, Habit updatedHabit) async {
    try {
      await _firestore.collection('habits').doc(habitId).update(<String, dynamic>{
        'title': updatedHabit.title,
        'description': updatedHabit.description,
        'emoji': updatedHabit.emoji,
        'category': updatedHabit.category.name,
        'frequency': updatedHabit.frequency.name,
        'preferredTime': updatedHabit.preferredTime.name,
        'targetMinutes': updatedHabit.targetMinutes,
        'isActive': updatedHabit.isActive,
      });

      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index != -1) {
        _habits[index] = updatedHabit;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to update habit: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete/archive a habit in Firebase
  Future<bool> deleteHabit(String habitId) async {
    try {
      await _firestore.collection('habits').doc(habitId).update(<String, dynamic>{
        'isActive': false,
      });

      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index != -1) {
        _habits[index] = _habits[index].copyWith(isActive: false);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to delete habit: $e';
      notifyListeners();
      return false;
    }
  }
}
