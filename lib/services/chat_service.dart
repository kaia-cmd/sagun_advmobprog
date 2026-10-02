import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

// Lab Activity 6: Firestore-backed chat between Firebase users. Users are
// mirrored into the "Users" collection by UserService.saveFirebaseProfile so
// the chat list has someone to show; messages live in per-pair chat rooms.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('Users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();

    final MessageModel newMessage = MessageModel(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
    );

    final String chatRoomID = _chatRoomId(currentUserId, receiverId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomID);

    await chatRoomRef.collection('messages').add(newMessage.toMap());

    // Unread indicator bookkeeping: a fresh message is "read" only by its
    // sender until the receiver opens the chat (markAsRead).
    await chatRoomRef.set({
      'participants': [currentUserId, receiverId],
      'lastMessage': message,
      'lastMessageTime': timestamp,
      'lastSenderId': currentUserId,
      'readBy': [currentUserId],
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    final String chatRoomID = _chatRoomId(userId, otherUserId);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Marks the chat room between [userId] and [otherUserId] as read by
  /// [userId] — call when [userId] opens that chat.
  Future<void> markAsRead(String userId, String otherUserId) async {
    final String chatRoomID = _chatRoomId(userId, otherUserId);
    await _firestore.collection('chat_rooms').doc(chatRoomID).set({
      'readBy': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  /// The chat room summary doc (lastMessage/lastSenderId/readBy) for a pair
  /// of users — used to show the unread dot and preview in the chat list.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatRoomInfo(
    String userId,
    String otherUserId,
  ) {
    final String chatRoomID = _chatRoomId(userId, otherUserId);
    return _firestore.collection('chat_rooms').doc(chatRoomID).snapshots();
  }

  /// True whenever [userId] has at least one chat room with an unread
  /// message — used for the badge on the Chat bottom nav tab.
  Stream<bool> hasUnreadMessages(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.any((doc) {
            final data = doc.data();
            final readBy = List<String>.from(data['readBy'] ?? []);
            return data['lastSenderId'] != userId && !readBy.contains(userId);
          });
        });
  }

  String _chatRoomId(String userId, String otherUserId) {
    final List<String> ids = [userId, otherUserId];
    ids.sort();
    return ids.join('_');
  }
}
