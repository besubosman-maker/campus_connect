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
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/email_service.dart';
import '../../services/listing_service.dart';
import '../../services/order_service.dart';
import '../../services/offer_service.dart';
import '../../services/chapa_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../chat/chat_screen.dart';
import '../rating/rate_seller_screen.dart';
import '../listing/listing_detail_screen.dart';

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
  final ChapaService _chapaService = ChapaService();
  final ImagePicker _picker = ImagePicker();
  final OfferService _offerService = OfferService();
  String _offerSubFilter = 'received'; // 'received' or 'sent'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
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
            Tab(
              icon: Icon(Icons.handshake_outlined),
              text: 'Bargains (ድርድር 🤝)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(user.uid),
          _buildSalesTab(user.uid),
          _buildOffersTab(user),
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

  Widget _buildOffersTab(UserModel currentUser) {
    final isReceived = _offerSubFilter == 'received';

    return Column(
      children: [
        // Sub-filter tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Received (የቀረቡልኝ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  selected: isReceived,
                  selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                  labelStyle: TextStyle(
                    color: isReceived ? AppConstants.primaryColor : Colors.black87,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _offerSubFilter = 'received');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Sent (ያቀረብኳቸው)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  selected: !isReceived,
                  selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                  labelStyle: TextStyle(
                    color: !isReceived ? AppConstants.primaryColor : Colors.black87,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _offerSubFilter = 'sent');
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<OfferModel>>(
            stream: isReceived
                ? _offerService.getSellerOffersStream(currentUser.uid)
                : _offerService.getBuyerOffersStream(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingIndicator(message: 'Loading bargaining offers...');
              }

              final offers = snapshot.data ?? [];

              if (offers.isEmpty) {
                return EmptyState(
                  icon: Icons.handshake_outlined,
                  title: isReceived ? 'No Offers Received' : 'No Offers Made',
                  message: isReceived
                      ? 'When buyers negotiate prices on your listings, you can accept, decline, or counter-offer here.'
                      : 'You have not made any price offers yet. Tap "Offer 🤝" on any listing to negotiate!',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  return _buildOfferCard(offers[index], isSeller: isReceived, currentUser: currentUser);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCounterOfferDialog(OfferModel offer) {
    final counterController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Counter-Offer (አዲስ ዋጋ ጥቀስ)', style: TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Listing Price: ${AppConstants.currencySymbol}${offer.listingPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Buyer Offered: ${AppConstants.currencySymbol}${offer.offerAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: counterController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Your Counter Price (ETB) *',
                      hintText: 'e.g. 850',
                      prefixText: 'ETB ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note for Buyer (Optional)',
                      hintText: 'e.g. Lowest I can do is 850 ETB',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final val = double.tryParse(counterController.text.trim());
                        if (val == null || val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSubmitting = true);
                        await _offerService.respondToOffer(
                          offerId: offer.id,
                          action: 'counter',
                          counterAmount: val,
                          sellerNote: noteController.text.trim(),
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Counter-offer sent to buyer!')),
                          );
                        }
                      },
                child: Text(isSubmitting ? 'Sending...' : 'Send Counter-Offer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(OfferModel offer, {required bool isSeller, required UserModel currentUser}) {
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 0);
    final discountETB = (offer.listingPrice - offer.offerAmount).clamp(0, 999999);
    final discountPercent = offer.listingPrice > 0 ? ((discountETB / offer.listingPrice) * 100).round() : 0;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (offer.status) {
      case 'accepted':
        badgeColor = const Color(0xFF059669);
        badgeText = 'Accepted ✓';
        badgeIcon = Icons.check_circle_outline;
        break;
      case 'countered':
        badgeColor = Colors.amber.shade800;
        badgeText = 'Countered (${currencyFormat.format(offer.counterAmount ?? 0)})';
        badgeIcon = Icons.swap_horiz_rounded;
        break;
      case 'declined':
        badgeColor = Colors.red.shade700;
        badgeText = 'Declined';
        badgeIcon = Icons.cancel_outlined;
        break;
      case 'pending':
      default:
        badgeColor = AppConstants.primaryColor;
        badgeText = 'Pending Offer';
        badgeIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: offer.status == 'accepted' ? const Color(0xFF059669).withOpacity(0.4) : Colors.grey.shade200,
          width: offer.status == 'accepted' ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d, hh:mm a').format(offer.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 18),

            // Listing summary
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImageHelper.buildImage(
                    imageUrl: offer.listingImage ?? '',
                    height: 54,
                    width: 54,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.listingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Original Price: ${currencyFormat.format(offer.listingPrice)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, decoration: TextDecoration.lineThrough),
                      ),
                      Text(
                        'Offer Price: ${currencyFormat.format(offer.offerAmount)} (-$discountPercent%)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (offer.buyerNote != null && offer.buyerNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: "${offer.buyerNote}"',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (offer.status == 'countered' && offer.counterAmount != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Seller counter-offered ${currencyFormat.format(offer.counterAmount)}'
                        '${offer.sellerNote != null && offer.sellerNote!.isNotEmpty ? ' ("${offer.sellerNote}")' : ''}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Actions for Seller when pending
            if (isSeller && offer.status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _offerService.respondToOffer(
                          offerId: offer.id,
                          action: 'accept',
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Offer accepted! Buyer notified.')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Counter', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCounterOfferDialog(offer),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Decline Offer',
                    onPressed: () async {
                      await _offerService.respondToOffer(
                        offerId: offer.id,
                        action: 'decline',
                      );
                    },
                  ),
                ],
              ),
            ]
            // Actions for Buyer when accepted
            else if (!isSeller && offer.status == 'accepted') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: Text('Checkout at Accepted Price (${currencyFormat.format(offer.offerAmount)}) 🎉'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListingDetailScreen(listingId: offer.listingId),
                      ),
                    );
                  },
                ),
              ),
            ]
            // Actions for Buyer when countered
            else if (!isSeller && offer.status == 'countered') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Accept Counter-Offer (${currencyFormat.format(offer.counterAmount ?? 0)})'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    await _offerService.respondToOffer(
                      offerId: offer.id,
                      action: 'accept',
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Accepted counter-offer! Proceeding to listing.')),
                      );
                      nav.push(
                        MaterialPageRoute(
                          builder: (context) => ListingDetailScreen(listingId: offer.listingId),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
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

            // SELLER DISPUTE REPORT BANNER (Buyer & Seller see the exact report text)
            if (order.isPaymentDisputed) ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade400, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem_rounded, color: Colors.red.shade700, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBuyer
                                ? 'Payment Reported: Not Received (ክፍያ አልተገኘም)'
                                : 'You Reported: Payment Not Received',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speaker_notes_outlined, size: 14, color: Colors.red.shade700),
                              const SizedBox(width: 5),
                              Text(
                                isBuyer ? "Seller's Report / Reason:" : "Your Report Note:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            order.disputeReason != null && order.disputeReason!.trim().isNotEmpty
                                ? order.disputeReason!
                                : 'Payment could not be verified in SMS inbox. Please check your transaction reference.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isBuyer) ...[
                      Text(
                        '💡 Please check your Telebirr (127) or CBE transaction message. If the code was wrong, tap "Re-Submit Proof" below to send the correct transaction ID or message the seller.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ] else ...[
                      Text(
                        'The buyer can see your report above and has been notified to re-submit the correct transaction message.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ],
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
                        'Payment Verified by Seller (${order.paymentMethod})! Ready for handshake meetup.',
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
                      order.isPaymentDisputed
                          ? Icons.refresh_rounded
                          : (order.paymentMethod.contains('Telebirr')
                              ? Icons.phone_android
                              : (order.paymentMethod.contains('CBE') ? Icons.account_balance : Icons.payments_outlined)),
                      size: 15,
                    ),
                    label: Text(
                      order.isPaymentDisputed
                          ? 'Re-Submit Proof (እንደገና ላክ)'
                          : (order.isPaymentProofSubmitted ? 'Update Proof' : 'Pay & Verify (ክፍያ)'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: order.isPaymentDisputed
                          ? Colors.red.shade700
                          : (order.paymentMethod.contains('Telebirr')
                              ? Colors.blue.shade700
                              : (order.paymentMethod.contains('CBE') ? Colors.purple.shade700 : Colors.teal.shade700)),
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

                // 3. Chat Button with Real-Time "New Message" Symbol / Badge
                StreamBuilder<bool>(
                  stream: _chatService.hasUnreadMessageStream(
                    currentUserId: isBuyer ? order.buyerId : order.sellerId,
                    otherUserId: isBuyer ? order.sellerId : order.buyerId,
                  ),
                  builder: (context, unreadSnapshot) {
                    final hasNewMessage = unreadSnapshot.data ?? false;
                    return OutlinedButton.icon(
                      icon: Badge(
                        isLabelVisible: hasNewMessage,
                        backgroundColor: Colors.redAccent,
                        smallSize: 9,
                        child: Icon(
                          hasNewMessage ? Icons.mark_chat_unread_rounded : Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: hasNewMessage ? Colors.redAccent : Colors.teal,
                        ),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Chat'),
                          if (hasNewMessage) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: hasNewMessage ? Colors.redAccent : Colors.teal,
                        side: BorderSide(
                          color: hasNewMessage ? Colors.redAccent : Colors.teal.shade300,
                          width: hasNewMessage ? 1.5 : 1.0,
                        ),
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
                    );
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
    final defaultReasons = [
      'No SMS arrived from 127 (Telebirr)',
      'Transaction reference not found in account',
      'Amount received does not match price',
      'Sent to wrong account number',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Report Payment Issue (ክፍያ አልተገኘም)',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select or type a reason why payment could not be confirmed. The buyer will see this report text in the app:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quick Reasons:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: defaultReasons.map((reason) {
                      return ActionChip(
                        label: Text(reason, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.grey.shade100,
                        onPressed: () {
                          setDialogState(() {
                            reasonController.text = reason;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Seller Report Note for Buyer',
                      hintText: 'e.g. Checked my Telebirr SMS and no money arrived with this reference code...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final text = reasonController.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  await _orderService.disputePayment(
                    order,
                    reason: text.isNotEmpty ? text : 'Payment SMS not received in seller account',
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Dispute reported! Buyer can now view your report note in the app.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
                child: const Text('Send Report to Buyer'),
              ),
            ],
          );
        },
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
    bool isInitializingChapa = false;
    bool isVerifyingChapa = false;
    String? chapaTxRef = order.transactionRef?.startsWith('chapa_') == true ? order.transactionRef : null;

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
                order.paymentMethod.contains('Chapa')
                    ? Icons.payment_rounded
                    : (order.paymentMethod.contains('Telebirr')
                        ? Icons.phone_android
                        : (order.paymentMethod.contains('CBE') ? Icons.account_balance : Icons.payments_outlined)),
                color: order.paymentMethod.contains('Chapa')
                    ? Colors.teal.shade700
                    : (order.paymentMethod.contains('Telebirr')
                        ? Colors.blue.shade800
                        : (order.paymentMethod.contains('CBE') ? Colors.purple.shade800 : Colors.green.shade800)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.paymentMethod.contains('Chapa')
                      ? 'Online Pay (Chapa API)'
                      : (order.paymentMethod.contains('Telebirr')
                          ? 'Telebirr Payment'
                          : (order.paymentMethod.contains('CBE') ? 'CBE Transfer' : 'Payment Details')),
                  style: const TextStyle(fontSize: 17),
                ),
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

                // AUTOMATED CHAPA API CHECKOUT CARD (FOR BUYER)
                if (isBuyer) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade50, Colors.teal.shade100.withOpacity(0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade400, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.teal.shade800, size: 22),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Instant Online Pay (Chapa API)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'AUTOMATED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pay in-app with Telebirr, CBE Birr, Awash, or Card with automated instant verification.',
                          style: TextStyle(fontSize: 11.5, color: Colors.teal.shade900),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: isInitializingChapa
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.payment_rounded, size: 16),
                            label: Text(
                              isInitializingChapa ? 'Opening Chapa Checkout...' : 'Pay with Chapa (ክፍያ ፈጽም)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: isInitializingChapa
                                ? null
                                : () async {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    final buyer = auth.userModel;
                                    if (buyer == null) return;
                                    final messenger = ScaffoldMessenger.of(context);

                                    setDialogState(() => isInitializingChapa = true);
                                    final initResult = await _chapaService.initializePayment(
                                      order: order,
                                      buyer: buyer,
                                    );
                                    setDialogState(() => isInitializingChapa = false);

                                    if (initResult.success && initResult.checkoutUrl != null) {
                                      setDialogState(() {
                                        chapaTxRef = initResult.txRef;
                                        refController.text = initResult.txRef ?? '';
                                      });
                                      await _orderService.updateOrderPaymentRef(order.id, initResult.txRef!);
                                      await ChapaService.openCheckout(initResult.checkoutUrl!);
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(initResult.errorMessage ?? 'Chapa connection failed'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        if (chapaTxRef != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: isVerifyingChapa
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.verified_outlined, size: 16),
                              label: Text(isVerifyingChapa ? 'Verifying with Chapa...' : 'Verify Chapa Payment (አረጋግጥ)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal.shade900,
                                side: BorderSide(color: Colors.teal.shade700, width: 1.5),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: isVerifyingChapa
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setDialogState(() => isVerifyingChapa = true);
                                      final verifyResult = await _chapaService.verifyPayment(chapaTxRef!);
                                      setDialogState(() => isVerifyingChapa = false);

                                      if (verifyResult.verified) {
                                        await _orderService.verifyPayment(order);
                                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(verifyResult.message ?? 'Payment verified successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(verifyResult.message ?? 'Payment pending. Complete checkout in Chapa then try again.'),
                                            backgroundColor: Colors.orange.shade800,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'OR DIRECT P2P TRANSFER (በእጅ/USSD)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
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
