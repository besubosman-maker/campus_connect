import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view messages')),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      drawer: const AppDrawer(currentTabIndex: 1),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppConstants.primaryColor),
            tooltip: 'Menu Bar',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Messages & Chats'),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.getUserChatsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading conversations...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error loading chats: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No Conversations Yet',
              message:
                  'When you browse marketplace items and tap "Chat with Seller", your conversations will appear here.',
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherId = chat.getOtherUserId(currentUser.uid);
              final otherParticipant = chat.getOtherParticipant(currentUser.uid);

              return StreamBuilder<QuerySnapshot>(
                // Query unread messages sent by the other user
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chat.id)
                    .collection('messages')
                    .where('read', isEqualTo: false)
                    .snapshots(),
                builder: (context, msgSnapshot) {
                  int unreadCount = 0;
                  if (msgSnapshot.hasData) {
                    unreadCount = msgSnapshot.data!.docs
                        .where((d) => d['senderId'] != currentUser.uid)
                        .length;
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                      backgroundImage: otherParticipant.photoUrl != null
                          ? CachedNetworkImageProvider(otherParticipant.photoUrl!)
                          : null,
                      child: otherParticipant.photoUrl == null
                          ? const Icon(Icons.person, color: AppConstants.primaryColor)
                          : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherParticipant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(chat.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: unreadCount > 0 ? AppConstants.primaryColor : Colors.grey[500],
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.lastMessage.isNotEmpty
                                  ? chat.lastMessage
                                  : 'Tap to start conversation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    onTap: () {
                      final otherUser = UserModel(
                        uid: otherId,
                        name: otherParticipant.name,
                        email: '',
                        photoUrl: otherParticipant.photoUrl,
                        joinedAt: DateTime.now(),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chat.id,
                            otherUser: otherUser,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('hh:mm a').format(time);
    } else if (difference.inDays < 7) {
      return DateFormat('E').format(time);
    } else {
      return DateFormat('MM/dd').format(time);
    }
  }
}
