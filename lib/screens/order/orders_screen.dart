import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/email_service.dart';
import '../../services/listing_service.dart';
import '../../services/order_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../chat/chat_screen.dart';
import '../rating/rate_seller_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialTabIndex;

  const OrdersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final ListingService _listingService = ListingService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openChatWithUser(UserModel otherUser) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;
    if (currentUser == null) return;

    try {
      final chatId = await _chatService.startOrGetChat(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUser: otherUser,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

  void _onEmailUser({
    required String recipientEmail,
    required String recipientName,
    required String listingTitle,
    required String role,
    required String meetupLocation,
    required String meetupTime,
  }) async {
    if (recipientEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address is not available')),
      );
      return;
    }

    final subject = '[CampusConnect] Regarding order for: $listingTitle';
    final body = 'Hi $recipientName,\n\n'
        'I am messaging you from CampusConnect regarding our order for "$listingTitle".\n\n'
        'Meetup details:\n'
        '• Location: $meetupLocation\n'
        '• Time: $meetupTime\n\n'
        'Let me know if this works for you or if we need to adjust anything.\n\n'
        'Thanks!';

    final success = await EmailService.launchEmailApp(
      recipientEmail: recipientEmail,
      subject: subject,
      body: body,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch email app. Address: $recipientEmail')),
      );
    }
  }

  void _onRateSeller(OrderModel order) async {
    try {
      final seller = await _authService.getUserProfile(order.sellerId);
      final listing = await _listingService.getListingById(order.listingId);

      if (seller == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller profile could not be loaded.')),
          );
        }
        return;
      }

      final listingObj = listing ??
          ListingModel(
            id: order.listingId,
            sellerId: order.sellerId,
            title: order.listingTitle,
            description: '',
            price: order.listingPrice,
            category: 'Campus Item',
            images: order.listingImage != null ? [order.listingImage!] : [],
            status: 'sold',
            createdAt: order.createdAt,
            searchKeywords: [],
          );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RateSellerScreen(
              seller: seller,
              listing: listingObj,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your orders.')),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Orders & Payments (ትዕዛዞች)'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppConstants.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_bag_outlined),
              text: 'My Purchases',
            ),
            Tab(
              icon: Icon(Icons.storefront_outlined),
              text: 'Incoming Sales',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(user.uid),
          _buildSalesTab(user.uid),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab(String currentUserId) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getBuyerOrdersStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading purchases...');
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No purchases yet',
            message: 'Browse listings and order items for local community meetups.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], isBuyer: true);
          },
        );
      },
    );
  }

  Widget _buildSalesTab(String currentUserId) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getSellerOrdersStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading incoming orders...');
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.sell_outlined,
            title: 'No incoming orders',
            message: 'When buyers place orders for your listings, they will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], isBuyer: false);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, {required bool isBuyer}) {
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);
    final otherPartyName = isBuyer ? order.sellerName : order.buyerName;
    final otherPartyEmail = isBuyer ? order.sellerEmail : order.buyerEmail;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (order.status) {
      case 'accepted':
        statusColor = Colors.blue.shade700;
        statusText = 'Meetup Accepted';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'completed':
        statusColor = Colors.green.shade700;
        statusText = 'Completed / Sold';
        statusIcon = Icons.verified;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade700;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'pending':
      default:
        statusColor = Colors.amber.shade800;
        statusText = isBuyer ? 'Pending Confirmation' : 'New Order Request';
        statusIcon = Icons.schedule;
        break;
    }

    Color payStatusColor;
    String payStatusText;
    IconData payStatusIcon;

    switch (order.paymentStatus) {
      case 'verified':
        payStatusColor = Colors.green.shade800;
        payStatusText = '✓ Payment Verified';
        payStatusIcon = Icons.verified;
        break;
      case 'proof_submitted':
        payStatusColor = Colors.orange.shade800;
        payStatusText = isBuyer ? 'Proof Sent (Pending)' : 'Action: Verify Payment';
        payStatusIcon = Icons.pending_actions;
        break;
      case 'disputed':
        payStatusColor = Colors.red.shade800;
        payStatusText = 'Payment Disputed';
        payStatusIcon = Icons.error_outline;
        break;
      case 'unpaid':
      default:
        payStatusColor = Colors.grey.shade700;
        payStatusText = 'Unpaid';
        payStatusIcon = Icons.hourglass_empty;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badges & Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Order Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Payment Verification Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: payStatusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: payStatusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(payStatusIcon, size: 13, color: payStatusColor),
                            const SizedBox(width: 4),
                            Text(
                              payStatusText,
                              style: TextStyle(
                                color: payStatusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(order.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Item Details Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: order.listingImage != null && order.listingImage!.isNotEmpty
                        ? AppImageHelper.buildImage(
                            imageUrl: order.listingImage!,
                            fit: BoxFit.cover,
                            placeholder: Container(color: Colors.grey[200]),
                            errorWidget: Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.shopping_bag, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.shopping_bag, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.listingTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(order.listingPrice),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBuyer ? 'Seller: $otherPartyName' : 'Buyer: $otherPartyName',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Meetup & Ethiopian Payment Info Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppConstants.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Meetup Spot: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                      ),
                      Expanded(
                        child: Text(
                          order.meetupLocation,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppConstants.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Proposed Time: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                      ),
                      Expanded(
                        child: Text(
                          order.meetupTime,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        order.paymentMethod.contains('Telebirr')
                            ? Icons.phone_android
                            : (order.paymentMethod.contains('CBE') ? Icons.account_balance : Icons.payments_outlined),
                        size: 16,
                        color: order.paymentMethod.contains('Telebirr')
                            ? Colors.blue.shade700
                            : (order.paymentMethod.contains('CBE') ? Colors.purple.shade700 : Colors.green.shade700),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Payment Method: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                      ),
                      Expanded(
                        child: Text(
                          order.paymentMethod,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: order.paymentMethod.contains('Telebirr')
                                ? Colors.blue.shade800
                                : (order.paymentMethod.contains('CBE') ? Colors.purple.shade800 : Colors.green.shade800),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (order.transactionRef != null && order.transactionRef!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, size: 15, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text(
                          'Transaction Ref: ',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                        ),
                        Expanded(
                          child: SelectableText(
                            order.transactionRef!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order.buyerNote != null && order.buyerNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Note: ',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                        ),
                        Expanded(
                          child: Text(
                            order.buyerNote!,
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // SELLER PAYMENT VERIFICATION BANNER (The Core Solution!)
            if (!isBuyer && order.isPaymentProofSubmitted) ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Buyer Submitted Payment Proof!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Transaction Ref: ${order.transactionRef ?? "Not provided"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💡 How to verify: Check your SMS inbox from 127 (Telebirr) or CBE. Verify you received ${currencyFormat.format(order.listingPrice)} matching this transaction reference.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                    if (order.paymentProofImage != null && order.paymentProofImage!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showProofImageModal(order.paymentProofImage!),
                        child: Row(
                          children: [
                            const Icon(Icons.image, size: 16, color: AppConstants.primaryColor),
                            const SizedBox(width: 6),
                            const Text(
                              'View Attached Receipt Screenshot',
                              style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Confirm Payment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _confirmVerifyPayment(order),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Not Received'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade400),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _confirmDisputePayment(order),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // VERIFIED CONFIRMATION BANNER
            if (order.isPaymentVerified) ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Verified by Seller (${order.paymentMethod})! Ready for campus handshake meetup.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Communication & Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 1. Pay / Submit Payment Proof Button (For Buyer)
                if (isBuyer && !order.isPaymentVerified) ...[
                  ElevatedButton.icon(
                    icon: Icon(
                      order.paymentMethod.contains('Telebirr')
                          ? Icons.phone_android
                          : (order.paymentMethod.contains('CBE') ? Icons.account_balance : Icons.payments_outlined),
                      size: 15,
                    ),
                    label: Text(
                      order.isPaymentProofSubmitted ? 'Update Proof' : 'Pay & Verify (ክፍያ)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: order.paymentMethod.contains('Telebirr')
                          ? Colors.blue.shade700
                          : (order.paymentMethod.contains('CBE') ? Colors.purple.shade700 : Colors.teal.shade700),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showPaymentDetailsDialog(order, isBuyer: isBuyer),
                  ),
                ],

                // 2. Direct Email Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: Text('Email ${isBuyer ? "Seller" : "Buyer"}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _onEmailUser(
                    recipientEmail: otherPartyEmail,
                    recipientName: otherPartyName,
                    listingTitle: order.listingTitle,
                    role: isBuyer ? 'Seller' : 'Buyer',
                    meetupLocation: order.meetupLocation,
                    meetupTime: order.meetupTime,
                  ),
                ),

                // 3. Chat Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final targetUid = isBuyer ? order.sellerId : order.buyerId;
                    final targetUser = await _authService.getUserProfile(targetUid);
                    if (targetUser != null && mounted) {
                      _openChatWithUser(targetUser);
                    }
                  },
                ),

                // 4. Accept / Decline for Seller
                if (!isBuyer && order.isPending) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      await _orderService.acceptOrder(order);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order accepted! Student buyer has been notified.')),
                        );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _confirmCancelOrder(order),
                  ),
                ],

                // 5. Handshake Complete
                if (order.isAccepted) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text('Mark Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _confirmCompleteOrder(order, isBuyer: isBuyer),
                  ),
                ],

                // 6. Cancel Request
                if (isBuyer && order.isPending) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel Request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _confirmCancelOrder(order),
                  ),
                ],

                // 7. Rate Seller
                if (isBuyer && order.isCompleted) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.star_rate_rounded, size: 16),
                    label: const Text('Rate Seller'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _onRateSeller(order),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this campus order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderService.cancelOrder(order);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order cancelled.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmCompleteOrder(OrderModel order, {required bool isBuyer}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Campus Meetup'),
        content: const Text(
          'Confirm that the in-person handshake meetup took place, the item was received, and payment was settled.\n\nThis will permanently mark the listing as SOLD.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderService.completeOrder(order);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction completed! Listing marked as sold.')),
                );

                if (isBuyer) {
                  _onRateSeller(order);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Confirm Completed'),
          ),
        ],
      ),
    );
  }

  void _confirmVerifyPayment(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 26),
            SizedBox(width: 8),
            Text('Verify Payment'),
          ],
        ),
        content: Text(
          'Did you receive ETB ${order.listingPrice.toStringAsFixed(2)} via ${order.paymentMethod} matching Transaction ID "${order.transactionRef}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderService.verifyPayment(order);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment verified! Buyer has been notified.')),
                );
              }
            },
            child: const Text('Yes, Payment Received'),
          ),
        ],
      ),
    );
  }

  void _confirmDisputePayment(OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Payment Not Received'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report that you have checked your SMS and this transaction was not found:',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Transaction number not found in my Telebirr SMS',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderService.disputePayment(order, reason: reasonController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dispute recorded. Buyer notified to check their transaction message.')),
                );
              }
            },
            child: const Text('Report Dispute'),
          ),
        ],
      ),
    );
  }

  void _showProofImageModal(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Receipt Screenshot', style: TextStyle(fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: InteractiveViewer(
                child: AppImageHelper.buildImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetailsDialog(OrderModel order, {required bool isBuyer}) async {
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);
    final refController = TextEditingController(text: order.transactionRef ?? '');
    String? proofBase64;
    bool isUploadingProof = false;

    String? telebirr = order.paymentDetails;
    String? cbe = order.paymentDetails;
    String? cbeName;

    try {
      final seller = await _authService.getUserProfile(order.sellerId);
      if (seller != null) {
        if (seller.telebirrNumber != null && seller.telebirrNumber!.isNotEmpty) {
          telebirr = seller.telebirrNumber;
        }
        if (seller.cbeAccount != null && seller.cbeAccount!.isNotEmpty) {
          cbe = seller.cbeAccount;
          cbeName = seller.cbeAccountName;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                order.paymentMethod.contains('Telebirr')
                    ? Icons.phone_android
                    : (order.paymentMethod.contains('CBE') ? Icons.account_balance : Icons.payments_outlined),
                color: order.paymentMethod.contains('Telebirr')
                    ? Colors.blue.shade800
                    : (order.paymentMethod.contains('CBE') ? Colors.purple.shade800 : Colors.green.shade800),
              ),
              const SizedBox(width: 8),
              Text(
                order.paymentMethod.contains('Telebirr')
                    ? 'Telebirr Payment'
                    : (order.paymentMethod.contains('CBE') ? 'CBE Transfer' : 'Cash Details'),
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount: ${currencyFormat.format(order.listingPrice)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                ),
                const SizedBox(height: 12),
                if (order.paymentMethod.contains('Telebirr')) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller Telebirr Number (ቴሌብር):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          telebirr ?? (order.sellerEmail.isNotEmpty ? order.sellerEmail : 'Contact seller in Chat'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (telebirr != null && telebirr.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text('Copy'),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: telebirr!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Telebirr number copied to clipboard!')),
                                  );
                                },
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.phone, size: 14),
                              label: const Text('Dial *127#'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final uri = Uri.parse('tel:*127%23');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (order.paymentMethod.contains('CBE')) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CBE Account (የኢትዮጵያ ንግድ ባንክ):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          cbe ?? 'Contact seller for CBE Account number',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                        ),
                        if (cbeName != null && cbeName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Holder: $cbeName', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (cbe != null && cbe.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text('Copy'),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: cbe!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('CBE account copied to clipboard!')),
                                  );
                                },
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.phone, size: 14),
                              label: const Text('Dial *847#'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade700,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final uri = Uri.parse('tel:*847%23');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.handshake_outlined, color: Colors.green.shade800, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pay in Ethiopian Birr cash to ${order.sellerName} when you meet at ${order.meetupLocation}.',
                            style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Transaction Ref Input
                const Text(
                  'Transaction Reference / SMS Code (የግብይት ቁጥር)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Copy the Transaction number from your Telebirr (127) or CBE SMS message (e.g. CC47XXXXXX or FT26XXXXXX).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. CC479812 or FT2610293',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Screenshot Upload (Optional)
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: Text(proofBase64 == null ? 'Attach SMS Screenshot' : 'Screenshot Attached ✓'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: proofBase64 == null ? AppConstants.primaryColor : Colors.green,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: isUploadingProof
                          ? null
                          : () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 600,
                                maxHeight: 600,
                                imageQuality: 70,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                final b64 = base64Encode(bytes);
                                setDialogState(() {
                                  proofBase64 = 'data:image/jpeg;base64,$b64';
                                });
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Submit Proof Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isUploadingProof ? 'Submitting...' : 'Submit Proof to Seller (ማረጋገጫ ላክ)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isUploadingProof
                        ? null
                        : () async {
                            final ref = refController.text.trim();
                            if (ref.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter the Transaction Reference from your SMS.')),
                              );
                              return;
                            }

                            setDialogState(() => isUploadingProof = true);

                            await _orderService.submitPaymentProof(
                              order: order,
                              transactionRef: ref,
                              proofImage: proofBase64,
                            );

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment proof submitted! Seller will verify with their SMS.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
