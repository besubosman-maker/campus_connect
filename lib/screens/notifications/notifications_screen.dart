import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../listing/listing_detail_screen.dart';
import '../order/orders_screen.dart';
import '../requests/item_requests_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _handleNotificationTap(BuildContext context, NotificationModel notif) async {
    final notificationService = NotificationService();
    if (!notif.isRead) {
      await notificationService.markAsRead(notif.id);
    }

    if (!context.mounted) return;

    if (notif.type == 'offer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OrdersScreen(initialTabIndex: 2),
        ),
      );
    } else if (notif.type == 'order') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OrdersScreen(initialTabIndex: 0),
        ),
      );
    } else if ((notif.type == 'qa' || notif.type == 'listing') &&
        notif.targetId != null &&
        notif.targetId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListingDetailScreen(listingId: notif.targetId!),
        ),
      );
    } else if (notif.type == 'request') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ItemRequestsScreen(),
        ),
      );
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.handshake_rounded;
      case 'qa':
        return Icons.question_answer_rounded;
      case 'request':
        return Icons.campaign_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'offer':
        return const Color(0xFF059669);
      case 'qa':
        return Colors.blue.shade700;
      case 'request':
        return Colors.purple.shade700;
      case 'order':
        return Colors.teal.shade700;
      case 'chat':
        return AppConstants.primaryColor;
      default:
        return Colors.amber.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;
    final notificationService = NotificationService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifications (ማሳወቂያዎች 🔔)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await notificationService.markAllAsRead(user.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.getUserNotificationsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading notifications...');
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications Yet',
              message: 'When you receive offers, replies, or orders, they will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final color = _getColor(notif.type);
              final icon = _getIcon(notif.type);
              final timeFormatted = DateFormat('MMM d, hh:mm a').format(notif.createdAt);

              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) {
                  notificationService.deleteNotification(notif.id);
                },
                child: ListTile(
                  tileColor: notif.isRead ? Colors.transparent : AppConstants.primaryColor.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      if (!notif.isRead)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 10,
                            width: 10,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(
                        notif.body,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeFormatted,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  onTap: () => _handleNotificationTap(context, notif),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
