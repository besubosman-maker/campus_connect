import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference get _chatsRef => _firestore.collection('chats');

  /// Generate consistent chatId: sorted(uidA + "_" + uidB) so exactly one chat per user pair.
  String getChatId(String uidA, String uidB) {
    return ChatModel.getChatId(uidA, uidB);
  }

  /// Start a new chat or get the existing one between two users.
  Future<String> startOrGetChat({
    required UserModel currentUser,
    required UserModel otherUser,
  }) async {
    final chatId = getChatId(currentUser.uid, otherUser.uid);
    final chatDoc = _chatsRef.doc(chatId);

    final snapshot = await chatDoc.get();
    if (!snapshot.exists) {
      final chatData = {
        'members': [currentUser.uid, otherUser.uid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': {
          currentUser.uid: {
            'name': currentUser.name,
            'photoUrl': currentUser.photoUrl,
          },
          otherUser.uid: {
            'name': otherUser.name,
            'photoUrl': otherUser.photoUrl,
          },
        },
      };
      await chatDoc.set(chatData);
    } else {
      // Keep participant details updated if changed
      await chatDoc.update({
        'participants.${currentUser.uid}.name': currentUser.name,
        'participants.${currentUser.uid}.photoUrl': currentUser.photoUrl,
      });
    }

    return chatId;
  }

  /// Stream of all chats the user is a member of, sorted by latest message.
  Stream<List<ChatModel>> getUserChatsStream(String userId) {
    return _chatsRef
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return list;
    });
  }

  /// Stream real-time messages for a specific chat, ordered by timestamp ascending.
  Stream<List<MessageModel>> getChatMessagesStream(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
    });
  }

  /// Send a message within a chat and update the chat's lastMessage metadata.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final batch = _firestore.batch();

    // New message doc
    final messageRef = _chatsRef.doc(chatId).collection('messages').doc();
    batch.set(messageRef, {
      'senderId': senderId,
      'text': cleanText,
      'sentAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Update parent chat doc
    final chatDocRef = _chatsRef.doc(chatId);
    batch.update(chatDocRef, {
      'lastMessage': cleanText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'lastMessageRead': false,
    });

    await batch.commit();
  }

  /// Mark all unread messages sent to the current user as read.
  Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    try {
      final unreadQuery = await _chatsRef
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in unreadQuery.docs) {
        if (doc.data()['senderId'] != currentUserId) {
          batch.update(doc.reference, {'read': true});
          hasUpdates = true;
        }
      }

      // Also update parent chat doc read status
      final chatDoc = await _chatsRef.doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data() as Map<String, dynamic>?;
        if (data != null && data['lastSenderId'] != currentUserId && (data['lastMessageRead'] == false)) {
          batch.update(_chatsRef.doc(chatId), {'lastMessageRead': true});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Real-time stream checking whether there are unread messages from otherUser to currentUser.
  Stream<bool> hasUnreadMessageStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    final chatId = getChatId(currentUserId, otherUserId);
    return _chatsRef.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final lastSenderId = data['lastSenderId'] as String?;
      final lastMessageRead = data['lastMessageRead'] as bool? ?? true;
      final lastMessage = data['lastMessage'] as String? ?? '';
      return lastSenderId != null &&
          lastSenderId != currentUserId &&
          !lastMessageRead &&
          lastMessage.isNotEmpty;
    });
  }

  /// Real-time stream of the total count of unread chats for currentUser.
  Stream<int> getUnreadChatsCountStream(String currentUserId) {
    return getUserChatsStream(currentUserId).map((chats) {
      return chats.where((c) => c.hasUnread(currentUserId)).length;
    });
  }

  /// Check whether a chat exists between two users.
  /// (Constraint: Rate Seller only allowed if a chat exists between users).
  Future<bool> hasChatBetweenUsers(String uidA, String uidB) async {
    try {
      final chatId = getChatId(uidA, uidB);
      final doc = await _chatsRef.doc(chatId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking chat existence: $e');
      return false;
    }
  }
}
