import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'message_models.dart';

/// Service for messages and notifications
class MessageService extends ChangeNotifier {

  MessageService({
    FirebaseFirestore? firestore,
    this.userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final String? userId;

  List<Message> _messages = <Message>[];
  List<Conversation> _conversations = <Conversation>[];
  bool _isLoading = false;
  String? _error;
  MessageType? _typeFilter;

  // Getters
  List<Message> get messages => _filteredMessages;
  List<Message> get unreadMessages => _messages.where((Message m) => !m.isRead).toList();
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => unreadMessages.length;
  MessageType? get typeFilter => _typeFilter;

  List<Message> get _filteredMessages {
    if (_typeFilter == null) return _messages;
    return _messages.where((Message m) => m.type == _typeFilter).toList();
  }

  // Filters
  void setTypeFilter(MessageType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  /// Load all messages from Firebase
  Future<void> loadMessages() async {
    if (userId == null) {
      _error = 'Not logged in. Please log in to view messages.';
      notifyListeners();
      return;
    }
    final String currentUserId = userId!;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load messages for this user
      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _messages = messagesSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Message(
          id: doc.id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          type: _parseMessageType(data['type'] as String?),
          priority: _parseMessagePriority(data['priority'] as String?),
          senderId: data['senderId'] as String?,
          senderName: data['senderName'] as String?,
          actionUrl: data['actionUrl'] as String?,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isRead: data['isRead'] as bool? ?? false,
          readAt: (data['readAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      // Load conversations
      final QuerySnapshot<Map<String, dynamic>> conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      _conversations = conversationsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final Map<String, dynamic>? lastMsgData = data['lastMessage'] as Map<String, dynamic>?;
        
        return Conversation(
          id: doc.id,
          participantIds: List<String>.from(data['participantIds'] as List<dynamic>? ?? <dynamic>[]),
          participantNames: List<String>.from(data['participantNames'] as List<dynamic>? ?? <dynamic>[]),
          lastMessage: lastMsgData != null ? Message(
            id: lastMsgData['id'] as String? ?? '',
            title: lastMsgData['title'] as String? ?? '',
            body: lastMsgData['body'] as String? ?? '',
            type: _parseMessageType(lastMsgData['type'] as String?),
            senderName: lastMsgData['senderName'] as String?,
            createdAt: (lastMsgData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isRead: lastMsgData['isRead'] as bool? ?? false,
          ) : null,
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          unreadCount: data['unreadCount'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      _error = 'Failed to load messages: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'system':
        return MessageType.system;
      case 'announcement':
        return MessageType.announcement;
      case 'alert':
        return MessageType.alert;
      case 'reminder':
        return MessageType.reminder;
      case 'direct':
        return MessageType.direct;
      default:
        return MessageType.system;
    }
  }

  MessagePriority _parseMessagePriority(String? priority) {
    switch (priority) {
      case 'low':
        return MessagePriority.low;
      case 'normal':
        return MessagePriority.normal;
      case 'high':
        return MessagePriority.high;
      case 'urgent':
        return MessagePriority.urgent;
      default:
        return MessagePriority.normal;
    }
  }

  /// Mark a message as read in Firebase
  Future<bool> markAsRead(String messageId) async {
    try {
      final DateTime now = DateTime.now();
      await _firestore.collection('messages').doc(messageId).update(<String, dynamic>{
        'isRead': true,
        'readAt': Timestamp.fromDate(now),
      });

      final int index = _messages.indexWhere((Message m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isRead: true,
          readAt: now,
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to mark message as read: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mark all messages as read in Firebase
  Future<void> markAllAsRead() async {
    try {
      final DateTime now = DateTime.now();
      final WriteBatch batch = _firestore.batch();

      for (final Message message in _messages.where((Message m) => !m.isRead)) {
        batch.update(
          _firestore.collection('messages').doc(message.id),
          <String, dynamic>{
            'isRead': true,
            'readAt': Timestamp.fromDate(now),
          },
        );
      }

      await batch.commit();

      _messages = _messages.map((Message m) => m.copyWith(
        isRead: true,
        readAt: m.readAt ?? now,
      )).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to mark all as read: $e';
      notifyListeners();
    }
  }

  /// Delete a message in Firebase
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
      _messages = _messages.where((Message m) => m.id != messageId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete message: $e';
      notifyListeners();
      return false;
    }
  }

  /// Send a direct message
  Future<bool> sendMessage({
    required String recipientId,
    required String body,
    String? title,
  }) async {
    try {
      await _firestore.collection('messages').add(<String, dynamic>{
        'senderId': userId,
        'recipientId': recipientId,
        'title': title ?? '',
        'body': body,
        'type': MessageType.direct.name,
        'priority': MessagePriority.normal.name,
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
      return true;
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }
}
