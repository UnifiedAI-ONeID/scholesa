import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore service for the Scholesa platform.
/// Provides typed access to collections and common operations.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Access to the raw Firestore instance for advanced queries
  FirebaseFirestore get instance => _firestore;

  // ─────────────────────────────────────────────────────────────────────────────
  // Collection References
  // ─────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get sites =>
      _firestore.collection('sites');

  CollectionReference<Map<String, dynamic>> get sessions =>
      _firestore.collection('sessions');

  CollectionReference<Map<String, dynamic>> get sessionOccurrences =>
      _firestore.collection('sessionOccurrences');

  CollectionReference<Map<String, dynamic>> get enrollments =>
      _firestore.collection('enrollments');

  CollectionReference<Map<String, dynamic>> get attendanceRecords =>
      _firestore.collection('attendanceRecords');

  CollectionReference<Map<String, dynamic>> get presenceRecords =>
      _firestore.collection('presenceRecords');

  CollectionReference<Map<String, dynamic>> get missions =>
      _firestore.collection('missions');

  CollectionReference<Map<String, dynamic>> get skillAssessments =>
      _firestore.collection('skillAssessments');

  CollectionReference<Map<String, dynamic>> get messages =>
      _firestore.collection('messages');

  CollectionReference<Map<String, dynamic>> get habits =>
      _firestore.collection('habits');

  CollectionReference<Map<String, dynamic>> get habitLogs =>
      _firestore.collection('habitLogs');

  CollectionReference<Map<String, dynamic>> get learnerProfiles =>
      _firestore.collection('learnerProfiles');

  // ─────────────────────────────────────────────────────────────────────────────
  // Helper Methods
  // ─────────────────────────────────────────────────────────────────────────────

  /// Get a document by ID from a collection
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    String collection,
    String docId,
  ) {
    return _firestore.collection(collection).doc(docId).get();
  }

  /// Create a new document with auto-generated ID
  Future<DocumentReference<Map<String, dynamic>>> addDoc(
    String collection,
    Map<String, dynamic> data,
  ) {
    return _firestore.collection(collection).add(data);
  }

  /// Set a document (create or overwrite)
  Future<void> setDoc(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return _firestore
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
  }

  /// Update specific fields in a document
  Future<void> updateDoc(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _firestore.collection(collection).doc(docId).update(data);
  }

  /// Delete a document
  Future<void> deleteDoc(String collection, String docId) {
    return _firestore.collection(collection).doc(docId).delete();
  }

  /// Create a batch for atomic writes
  WriteBatch batch() => _firestore.batch();

  /// Run a transaction
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler,
  ) {
    return _firestore.runTransaction(transactionHandler);
  }

  /// Generate a new document ID without creating the document
  String generateId(String collection) {
    return _firestore.collection(collection).doc().id;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Query Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Get all documents in a collection
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String collection,
  ) {
    return _firestore.collection(collection).get();
  }

  /// Query documents where field equals value
  Query<Map<String, dynamic>> whereEquals(
    String collection,
    String field,
    Object value,
  ) {
    return _firestore.collection(collection).where(field, isEqualTo: value);
  }

  /// Query documents where field is in list
  Query<Map<String, dynamic>> whereIn(
    String collection,
    String field,
    List<Object> values,
  ) {
    return _firestore.collection(collection).where(field, whereIn: values);
  }

  /// Query documents where array contains value
  Query<Map<String, dynamic>> whereArrayContains(
    String collection,
    String field,
    Object value,
  ) {
    return _firestore
        .collection(collection)
        .where(field, arrayContains: value);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Timestamp Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Get current server timestamp
  FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  /// Convert DateTime to Firestore Timestamp
  Timestamp toTimestamp(DateTime dateTime) => Timestamp.fromDate(dateTime);

  /// Convert Firestore Timestamp to DateTime (null-safe)
  DateTime? fromTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
