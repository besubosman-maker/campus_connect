import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/listing_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/rating_stars.dart';
import '../../services/email_service.dart';
import '../../services/order_service.dart';
import '../chat/chat_screen.dart';
import '../order/orders_screen.dart';
import '../rating/rate_seller_screen.dart';
import 'create_listing_screen.dart';
import '../../services/marketplace_extension_service.dart';
import 'boost_listing_dialog.dart';
import '../../models/listing_question_model.dart';
import '../../services/question_service.dart';
import '../../services/notification_service.dart';
import 'make_offer_dialog.dart';
import '../../widgets/report_dialog.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final ListingService _listingService = ListingService();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final OrderService _orderService = OrderService();
  final QuestionService _questionService = QuestionService();

  ListingModel? _listing;
  UserModel? _seller;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final listing = await _listingService.getListingById(widget.listingId);
      if (listing == null) {
        setState(() {
          _errorMessage = 'Listing not found or has been removed.';
          _isLoading = false;
        });
        return;
      }

      final seller = await _authService.getUserProfile(listing.sellerId);

      if (mounted) {
        setState(() {
          _listing = listing;
          _seller = seller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading listing: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _onChatPressed() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to chat with sellers')),
      );
      return;
    }

    if (_seller == null || _listing == null) return;

    if (currentUser.uid == _seller!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own listing')),
      );
      return;
    }

    // Open chat or create one
    try {
      final chatId = await _chatService.startOrGetChat(
        currentUser: currentUser,
        otherUser: _seller!,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUser: _seller!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }

  void _onRateSellerPressed() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to rate sellers')),
      );
      return;
    }

    if (_seller == null || _listing == null) return;

    if (currentUser.uid == _seller!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot rate your own listing')),
      );
      return;
    }

    // Check if chat exists first
    final hasChat = await _chatService.hasChatBetweenUsers(currentUser.uid, _seller!.uid);
    if (!hasChat) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Chat Required First'),
            content: const Text(
              'To protect seller reputations against fake reviews, you must initiate a chat conversation with the seller before posting a rating.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _onChatPressed();
                },
                child: const Text('Start Chat Now'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      final rated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RateSellerScreen(
            seller: _seller!,
            listing: _listing!,
          ),
        ),
      );

      if (rated == true) {
        _loadData();
      }
    }
  }

  void _onEmailSellerPressed() async {
    if (_seller == null || _listing == null) return;

    final sellerEmail = _seller!.email.trim();
    if (sellerEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller email is not available.')),
      );
      return;
    }

    final listing = _listing!;
    final subject = '[CampusConnect] Inquiry about "${listing.title}"';
    final body = 'Hi ${_seller!.name},\n\n'
        'I am interested in buying your item "${listing.title}" on CampusConnect for ${AppConstants.currencySymbol}${listing.price.toStringAsFixed(2)}.\n\n'
        'Is it still available? I would like to arrange a meetup.\n\n'
        'Thanks!';

    final launched = await EmailService.launchEmailApp(
      recipientEmail: sellerEmail,
      subject: subject,
      body: body,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open email app. Seller email: $sellerEmail'),
        ),
      );
    }
  }

  void _showAskQuestionDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to ask a question.')),
      );
      return;
    }

    if (_listing == null || _seller == null) return;

    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: AppConstants.primaryColor),
                SizedBox(width: 8),
                Text('Ask a Question (ጥያቄ ጠይቅ)', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your question will be visible publicly on this listing for the seller and other students to see.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Is the battery health good? Any missing pages in textbook?',
                    border: OutlineInputBorder(),
                    isDense: true,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final q = controller.text.trim();
                        if (q.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSubmitting = true);
                        await _questionService.askQuestion(
                          listingId: _listing!.id,
                          sellerId: _seller!.uid,
                          question: q,
                          asker: currentUser,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Your question was posted!')),
                          );
                        }
                      },
                child: Text(isSubmitting ? 'Posting...' : 'Post Question'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAnswerQuestionDialog(ListingQuestionModel question) {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reply to Question (መልስ ስጥ)', style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q: "${question.question}"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Type your answer to help buyers...',
                    border: OutlineInputBorder(),
                    isDense: true,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final ans = controller.text.trim();
                        if (ans.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSubmitting = true);
                        await _questionService.answerQuestion(
                          questionId: question.id,
                          answer: ans,
                        );

                        await NotificationService().sendNotification(
                          userId: question.askerId,
                          title: '💬 Question Answered!',
                          body: 'The seller answered your question: "$ans"',
                          type: 'qa',
                          targetId: question.listingId,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Your reply has been published!')),
                          );
                        }
                      },
                child: Text(isSubmitting ? 'Replying...' : 'Post Reply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onBuyItemPressed() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to place an order.')),
      );
      return;
    }

    if (_seller == null || _listing == null) return;

    if (currentUser.uid == _seller!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot purchase your own item.')),
      );
      return;
    }

    _showOrderBottomSheet(currentUser);
  }

  void _showOrderBottomSheet(UserModel currentUser) {
    final listing = _listing!;
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);

    final locations = [
      'Public Café / Coffee Shop',
      'Mall / Shopping Center',
      'Bank / Telebirr Center',
      'Campus / University Gate',
      'Supermarket / Market Center',
      'Other Public Place',
    ];

    final times = [
      'Today',
      'Tomorrow afternoon',
      'This weekend',
      'Flexible / Any time',
    ];

    final paymentMethods = AppConstants.ethiopianPaymentMethods;
    String selectedLocation = locations[0];
    String selectedTime = times[0];
    String selectedPayment = _seller?.preferredPayment != null && paymentMethods.contains(_seller!.preferredPayment)
        ? _seller!.preferredPayment!
        : AppConstants.paymentTelebirr;

    final customLocationController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Place Order (ትዕዛዝ ማዘዣ)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Item Info Row
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: listing.images.isNotEmpty
                                ? AppImageHelper.buildImage(
                                    imageUrl: listing.images.first,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.shopping_bag),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currencyFormat.format(listing.price),
                                style: const TextStyle(
                                  color: AppConstants.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ethiopian Payment Method Selection
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        const Text(
                          'Ethiopian Payment Method (የክፍያ ዘዴ)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: paymentMethods.map((pm) {
                        final isSelected = selectedPayment == pm;
                        return ChoiceChip(
                          avatar: Icon(
                            pm.contains('Telebirr')
                                ? Icons.phone_android
                                : (pm.contains('CBE') ? Icons.account_balance : Icons.payments_outlined),
                            size: 16,
                            color: isSelected ? AppConstants.primaryColor : Colors.grey[700],
                          ),
                          label: Text(pm),
                          selected: isSelected,
                          selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            color: isSelected ? AppConstants.primaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedPayment = pm);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Dynamic payment guidance card
                    if (selectedPayment.contains('Chapa')) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payment, color: Colors.teal.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Automated API Checkout: Pay in-app securely with Telebirr, CBE Birr, Awash, or Card via Chapa.',
                                style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedPayment.contains('Telebirr')) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone_android, color: Colors.blue.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _seller?.telebirrNumber != null && _seller!.telebirrNumber!.isNotEmpty
                                    ? 'Seller Telebirr: ${_seller!.telebirrNumber}\nTransfer via Telebirr or dial *127# on meetup.'
                                    : 'Pay via Telebirr transfer or dial *127# during campus meetup.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedPayment.contains('CBE')) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance, color: Colors.purple.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _seller?.cbeAccount != null && _seller!.cbeAccount!.isNotEmpty
                                    ? 'CBE Account: ${_seller!.cbeAccount} (${_seller!.cbeAccountName ?? _seller!.name})\nTransfer via CBE Mobile Banking or dial *847#.'
                                    : 'Transfer via Commercial Bank of Ethiopia (CBE Birr / Mobile Banking).',
                                style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payments_outlined, color: Colors.green.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pay in Ethiopian Birr (ETB) cash upon inspecting the item on campus.',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Campus Meetup Location
                    const Text(
                      'Campus Meetup Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: locations.map((loc) {
                        final isSelected = selectedLocation == loc;
                        return ChoiceChip(
                          label: Text(loc),
                          selected: isSelected,
                          selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            color: isSelected ? AppConstants.primaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedLocation = loc);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (selectedLocation == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customLocationController,
                        decoration: const InputDecoration(
                          hintText: 'Enter specific campus spot (e.g. Engineering Bldg Rm 101)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Proposed Meetup Time
                    const Text(
                      'Preferred Meetup Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: times.map((tm) {
                        final isSelected = selectedTime == tm;
                        return ChoiceChip(
                          label: Text(tm),
                          selected: isSelected,
                          selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            color: isSelected ? AppConstants.primaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedTime = tm);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Buyer Note
                    const Text(
                      'Note for Seller (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. I have exact cash or will transfer via Telebirr',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Order Button
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: isSubmitting ? 'Submitting Order...' : 'Confirm Order (${currencyFormat.format(listing.price)})',
                        isLoading: isSubmitting,
                        icon: Icons.check_circle_outline,
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final finalLocation = selectedLocation == 'Other'
                                    ? (customLocationController.text.trim().isNotEmpty
                                        ? customLocationController.text.trim()
                                        : 'Campus Grounds')
                                    : selectedLocation;

                                setSheetState(() => isSubmitting = true);

                                try {
                                  final paymentInfo = selectedPayment.contains('Telebirr')
                                      ? _seller?.telebirrNumber
                                      : (selectedPayment.contains('CBE') ? _seller?.cbeAccount : null);

                                  await _orderService.createOrder(
                                    listingId: listing.id,
                                    listingTitle: listing.title,
                                    listingPrice: listing.price,
                                    listingImage: listing.images.isNotEmpty ? listing.images.first : null,
                                    sellerId: listing.sellerId,
                                    sellerName: _seller?.name ?? 'Campus Seller',
                                    sellerEmail: _seller?.email ?? '',
                                    buyerId: currentUser.uid,
                                    buyerName: currentUser.name,
                                    buyerEmail: currentUser.email,
                                    meetupLocation: finalLocation,
                                    meetupTime: selectedTime,
                                    buyerNote: noteController.text.trim().isNotEmpty
                                        ? noteController.text.trim()
                                        : null,
                                    paymentMethod: selectedPayment,
                                    paymentDetails: paymentInfo,
                                  );

                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (mounted) {
                                    _showOrderSuccessDialog(finalLocation, selectedTime, selectedPayment);
                                  }
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Order failed: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOrderSuccessDialog(String location, String time, String paymentMethod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Order Placed! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your order request was sent to ${_seller?.name ?? "the seller"}.'),
            const SizedBox(height: 10),
            Text('• Meetup: $location'),
            Text('• Time: $time'),
            Text('• Payment: $paymentMethod'),
            const SizedBox(height: 12),
            const Text(
              'The seller received an email alert. You can view payment details and dial Telebirr/CBE USSD directly in Campus Orders.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Browsing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrdersScreen(initialTabIndex: 0)),
              );
            },
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading item details...'),
      );
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing Detail')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Listing not found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.userModel?.uid == listing.sellerId;
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          listing.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.userModel;
              final isFav = user?.favorites.contains(listing.id) ?? false;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : Colors.grey,
                ),
                tooltip: isFav ? 'Remove from Favorites' : 'Save to Favorites',
                onPressed: user == null
                    ? null
                    : () async {
                        await MarketplaceExtensionService().toggleFavorite(
                          uid: user.uid,
                          listingId: listing.id,
                          isCurrentlyFavorite: isFav,
                        );
                      },
              );
            },
          ),
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.outlined_flag_rounded, color: Colors.grey),
              tooltip: 'Report Listing (አሳውቅ)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ReportDialog(
                    targetType: 'listing',
                    targetId: listing.id,
                    targetTitle: listing.title,
                  ),
                );
              },
            ),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'boost') {
                  final boosted = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => BoostListingDialog(listing: listing),
                  );
                  if (boosted == true) _loadData();
                } else if (val == 'edit') {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateListingScreen(existingListing: listing),
                    ),
                  );
                  if (updated == true) _loadData();
                } else if (val == 'toggle_status') {
                  final newStatus = listing.isAvailable ? 'sold' : 'available';
                  await _listingService.updateListingStatus(listing.id, newStatus);
                  _loadData();
                } else if (val == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Listing'),
                      content: const Text('Are you sure you want to permanently delete this listing?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await Provider.of<ListingProvider>(context, listen: false)
                        .deleteListing(listing.id, listing.images);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'boost',
                  child: Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, size: 20, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text('Boost Listing 🚀', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Listing'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(listing.isAvailable ? Icons.check_circle_outline : Icons.replay, size: 20),
                      SizedBox(width: 8),
                      Text(listing.isAvailable ? 'Mark as Sold' : 'Mark as Available'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Carousel
                  if (listing.images.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                            child: PageView.builder(
                              itemCount: listing.images.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return AppImageHelper.buildImage(
                                  imageUrl: listing.images[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: Container(
                                    color: Colors.grey[200],
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Indicator Dots
                          if (listing.images.length > 1)
                            Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  listing.images.length,
                                  (dotIndex) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _currentImageIndex == dotIndex ? 22 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == dotIndex
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Sold Overlay Badge
                          if (listing.isSold)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'ITEM SOLD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),

                          // Featured VIP Promotion Badge
                          if (listing.isBoostedActive)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.shade900.withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'FEATURED VIP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                      ),
                      child: const Center(
                        child: Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price & Category Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currencyFormat.format(listing.price),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: listing.isAvailable ? const Color(0xFF059669) : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      listing.isAvailable ? 'Available on Campus' : 'Item Sold',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: listing.isAvailable ? const Color(0xFF059669) : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppConstants.primaryColor.withOpacity(0.1),
                                    AppConstants.primaryColor.withOpacity(0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppConstants.primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tag_rounded, size: 14, color: AppConstants.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    listing.category,
                                    style: const TextStyle(
                                      color: AppConstants.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Date Posted
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 15, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Posted ${DateFormat('MMMM d, y').format(listing.createdAt)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                        const Divider(height: 32),

                        // Seller Card
                        const Text(
                          'Seller Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [AppConstants.primaryColor, Color(0xFF3B82F6)],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.white,
                                      backgroundImage: _seller?.photoUrl != null
                                          ? AppImageHelper.getImageProvider(_seller!.photoUrl!)
                                          : null,
                                      child: _seller?.photoUrl == null
                                          ? const Icon(Icons.person, color: AppConstants.primaryColor, size: 28)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _seller?.name ?? 'Community Member',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (_seller?.isIdVerified == true || _seller?.isVerifiedSeller == true)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.green.shade300),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.verified, color: Colors.green, size: 13),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Verified',
                                                      style: TextStyle(
                                                        color: Colors.green.shade900,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        RatingStars(
                                          rating: _seller?.rating ?? 0.0,
                                          count: _seller?.ratingCount ?? 0,
                                          starSize: 16,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Member since ${_seller != null ? DateFormat('MMM y').format(_seller!.joinedAt) : 'recently'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!isOwner) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                // Instant Direct Contact Options (Phone Call & Telegram)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.phone_rounded, size: 16),
                                        label: const Text('Call Seller'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () {
                                          final phone = listing.sellerPhone ?? _seller?.phoneNumber ?? _seller?.telebirrNumber;
                                          if (phone != null && phone.isNotEmpty) {
                                            MarketplaceExtensionService().launchPhoneCall(phone);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Seller has not listed a phone number. Use in-app chat.')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.send_rounded, size: 16),
                                        label: const Text('Telegram'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0284C7),
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () {
                                          final tg = listing.sellerTelegram ?? _seller?.telegramUsername;
                                          if (tg != null && tg.isNotEmpty) {
                                            MarketplaceExtensionService().launchTelegram(tg);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Seller has not linked a Telegram username. Use in-app chat.')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.email_outlined, size: 16),
                                        label: const Text('Email Seller'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppConstants.primaryColor,
                                          side: BorderSide(color: AppConstants.primaryColor.withOpacity(0.3)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: _onEmailSellerPressed,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.star_outline_rounded, size: 16),
                                        label: const Text('Rate Seller'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.amber.shade800,
                                          side: BorderSide(color: Colors.amber.shade400),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: _onRateSellerPressed,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Community Q&A Section
                        _buildQuestionsSection(listing, auth.userModel),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: isOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: listing.isAvailable ? 'Mark as Sold' : 'Mark Available',
                            icon: listing.isAvailable ? Icons.check_circle_outline : Icons.replay,
                            isOutlined: true,
                            onPressed: () async {
                              final newStatus = listing.isAvailable ? 'sold' : 'available';
                              await _listingService.updateListingStatus(listing.id, newStatus);
                              _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Edit Listing',
                            icon: Icons.edit_outlined,
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateListingScreen(existingListing: listing),
                                ),
                              );
                              if (updated == true) _loadData();
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Quick Email Button
                        Container(
                          height: 48,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Email Seller',
                            icon: const Icon(Icons.email_outlined, color: AppConstants.primaryColor, size: 20),
                            onPressed: _onEmailSellerPressed,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Chat Button with New Message Symbol / Badge
                        Expanded(
                          flex: 3,
                          child: StreamBuilder<bool>(
                            stream: auth.userModel != null && _seller != null
                                ? _chatService.hasUnreadMessageStream(
                                    currentUserId: auth.userModel!.uid,
                                    otherUserId: _seller!.uid,
                                  )
                                : Stream.value(false),
                            builder: (context, unreadSnapshot) {
                              final hasNew = unreadSnapshot.data ?? false;
                              return OutlinedButton.icon(
                                icon: Badge(
                                  isLabelVisible: hasNew,
                                  backgroundColor: Colors.redAccent,
                                  smallSize: 8,
                                  child: Icon(
                                    hasNew
                                        ? Icons.mark_chat_unread_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    size: 15,
                                    color: hasNew ? Colors.redAccent : AppConstants.primaryColor,
                                  ),
                                ),
                                label: Text(
                                  hasNew ? 'Chat*' : 'Chat',
                                  style: TextStyle(
                                    color: hasNew ? Colors.redAccent : AppConstants.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  side: BorderSide(
                                    color: hasNew ? Colors.redAccent : AppConstants.primaryColor,
                                    width: hasNew ? 1.5 : 1.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: _onChatPressed,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Make an Offer (Bargaining) Button
                        Expanded(
                          flex: 4,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.handshake_outlined, size: 16),
                            label: const Text(
                              'Offer 🤝',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: listing.isAvailable
                                ? () {
                                    final currentUser = auth.userModel;
                                    if (currentUser == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please log in to make an offer.')),
                                      );
                                      return;
                                    }
                                    if (_seller == null) return;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => MakeOfferDialog(
                                        listing: listing,
                                        currentUser: currentUser,
                                        seller: _seller!,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Buy Item Button
                        Expanded(
                          flex: 5,
                          child: CustomButton(
                            text: listing.isAvailable ? 'Buy Item' : 'Sold',
                            icon: Icons.shopping_bag_outlined,
                            onPressed: listing.isAvailable ? _onBuyItemPressed : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(ListingModel listing, UserModel? currentUser) {
    final isSeller = currentUser != null && currentUser.uid == listing.sellerId;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.question_answer_outlined, color: AppConstants.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Questions & Answers (ጥያቄና መልስ)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              if (!isSeller)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppConstants.primaryColor,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ask', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _showAskQuestionDialog,
                ),
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<ListingQuestionModel>>(
            stream: _questionService.getQuestionsStream(listing.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final questions = snapshot.data ?? [];

              if (questions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'No public questions asked yet.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        if (!isSeller) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _showAskQuestionDialog,
                            child: const Text('Have a question? Ask the seller publicly!'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: questions.map((q) {
                  final hasUpvoted = currentUser != null && q.upvotedUserIds.contains(currentUser.uid);

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Q: ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 14),
                            ),
                            Expanded(
                              child: Text(
                                q.question,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: currentUser == null
                                  ? null
                                  : () => _questionService.toggleUpvote(
                                        questionId: q.id,
                                        userId: currentUser.uid,
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      hasUpvoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                      size: 15,
                                      color: hasUpvoted ? AppConstants.primaryColor : Colors.grey,
                                    ),
                                    if (q.upvotes > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '${q.upvotes}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasUpvoted ? AppConstants.primaryColor : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Asked by ${q.askerName} • ${DateFormat('MMM d').format(q.createdAt)}',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                        ),

                        // Answer if present
                        if (q.isAnswered) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF059669).withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Seller',
                                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.answer!,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isSeller) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.reply_rounded, size: 16, color: AppConstants.primaryColor),
                              label: const Text('Reply to Question', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _showAnswerQuestionDialog(q),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
