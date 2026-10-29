import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/item_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/item_request_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../chat/chat_screen.dart';

class ItemRequestsScreen extends StatefulWidget {
  const ItemRequestsScreen({super.key});

  @override
  State<ItemRequestsScreen> createState() => _ItemRequestsScreenState();
}

class _ItemRequestsScreenState extends State<ItemRequestsScreen> {
  final ItemRequestService _requestService = ItemRequestService();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Textbooks & Study Materials',
    'Electronics & Gadgets',
    'Dorm & Room Essentials',
    'Clothing & Fashion',
    'Sports & Fitness',
    'Services & Tutoring',
    'Other',
  ];

  void _openChatWithRequester(ItemRequestModel request) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to contact the requester')),
      );
      return;
    }

    if (currentUser.uid == request.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own request')),
      );
      return;
    }

    try {
      final requesterUser = await _authService.getUserProfile(request.userId);
      if (requesterUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find requester profile')),
          );
        }
        return;
      }

      final chatId = await _chatService.startOrGetChat(
        currentUser: currentUser,
        otherUser: requesterUser,
      );

      // Send initial friendly message about the request
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: currentUser.uid,
        text: '👋 Hi ${request.userName}! I saw your request for "${request.title}" on the Wanted Board. I have this item available!',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUser: requesterUser,
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

  void _showCreateRequestDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to post a request')),
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final budgetController = TextEditingController();
    final locationController = TextEditingController();
    String category = _categories[1]; // Textbooks default
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: AppConstants.primaryColor, size: 28),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Looking For / Request an Item\n(የምፈልገው ዕቃ - ፈልጉልኝ)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Item You Are Looking For *',
                        hintText: 'e.g. Calculus 9th Edition Book, Dorm Kettle',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Details / Condition Preferred *',
                        hintText: 'e.g. Can be used or new, urgently needed before midterms',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: budgetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Budget (ETB) *',
                              hintText: 'e.g. 500',
                              prefixText: 'ETB ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _categories
                                .where((c) => c != 'All')
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => category = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Campus Location / Dorm Spot',
                        hintText: 'e.g. Main Campus Library, Block 24, 6 Kilo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: isSubmitting ? 'Posting...' : 'Post Request (ለጥፍ 📢)',
                        isLoading: isSubmitting,
                        icon: Icons.check_circle_outline,
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final desc = descController.text.trim();
                          final budget = double.tryParse(budgetController.text.trim()) ?? 0.0;
                          final loc = locationController.text.trim().isEmpty
                              ? 'Campus Meetup'
                              : locationController.text.trim();

                          if (title.isEmpty || desc.isEmpty || budget <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill item title, description and budget')),
                            );
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          final newReq = ItemRequestModel(
                            id: '',
                            userId: currentUser.uid,
                            userName: currentUser.name,
                            userAvatar: currentUser.photoUrl,
                            userEmail: currentUser.email,
                            title: title,
                            description: desc,
                            category: category,
                            budgetETB: budget,
                            campusLocation: loc,
                            contactPhone: currentUser.phoneNumber,
                            contactTelegram: currentUser.telegramUsername,
                            createdAt: DateTime.now(),
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          await _requestService.createRequest(newReq);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }

                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Your request is now live on the Wanted Board!')),
                            );
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 0);
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.userModel?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Wanted Board (ፈልጉልኝ 📢)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Wanted Board',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('About Wanted Board (ፈልጉልኝ)'),
                  content: const Text(
                    'Looking for a textbook, dorm item, or gadget that is not listed?\n\n'
                    '1. Post what you need and your budget in ETB.\n'
                    '2. Sellers with matching items can tap "I Have This!" to chat with you directly.\n'
                    '3. Fast, campus-friendly student peer matching!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Post Request (ፈልጉልኝ)'),
        onPressed: _showCreateRequestDialog,
      ),
      body: Column(
        children: [
          // Category selector bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppConstants.primaryColor.withOpacity(0.18),
                    labelStyle: TextStyle(
                      color: isSelected ? AppConstants.primaryColor : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Stream of Requests
          Expanded(
            child: StreamBuilder<List<ItemRequestModel>>(
              stream: _requestService.getOpenRequestsStream(
                category: _selectedCategory,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading campus requests...');
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No Active Requests',
                    message: 'Be the first to post what you need on campus, and let sellers find you!',
                    actionLabel: '+ Post What You Need',
                    onAction: _showCreateRequestDialog,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final isMyRequest = currentUserId == req.userId;
                    final timeAgo = DateFormat('MMM d, y').format(req.createdAt);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isMyRequest ? AppConstants.primaryColor.withOpacity(0.4) : Colors.grey.shade200,
                          width: isMyRequest ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: user info + budget badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                                  child: req.userAvatar != null
                                      ? ClipOval(
                                          child: AppImageHelper.buildImage(
                                            imageUrl: req.userAvatar!,
                                            height: 36,
                                            width: 36,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'S',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            req.userName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (isMyRequest) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppConstants.primaryColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'You',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        '$timeAgo • 📍 ${req.campusLocation}',
                                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Budget',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        currencyFormat.format(req.budgetETB),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Item title & description
                            Text(
                              req.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              req.description,
                              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.3),
                            ),
                            const SizedBox(height: 10),

                            // Category tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🏷️ ${req.category}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Actions
                            if (isMyRequest) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                      label: const Text('Mark as Found', style: TextStyle(fontSize: 12, color: Colors.green)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.green),
                                      ),
                                      onPressed: () async {
                                        await _requestService.updateStatus(req.id, 'fulfilled');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Marked request as fulfilled!')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Delete Request',
                                    onPressed: () async {
                                      await _requestService.deleteRequest(req.id);
                                    },
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                  label: const Text(
                                    'I Have This! / አለኝ (አናግር)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () => _openChatWithRequester(req),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
