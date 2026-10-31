import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/loading_indicator.dart';
import '../chat/chat_list_screen.dart';
import '../listing/create_listing_screen.dart';
import '../listing/listing_detail_screen.dart';
import '../listing/my_listings_screen.dart';
import '../order/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/chat_service.dart';
import '../../services/admin_service.dart';
import '../../services/marketplace_extension_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../listing/favorites_screen.dart';
import '../requests/item_requests_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../admin/admin_login_screen.dart';
import '../profile/verify_id_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final provider = Provider.of<ListingProvider>(context, listen: false);
      if (provider.hasMore && !provider.isLoadingMore) {
        provider.fetchMoreListings();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Navigation pages
    final pages = [
      _buildBrowseTab(),
      const ChatListScreen(),
      const MyListingsScreen(),
      const ProfileScreen(),
    ];

    final auth = Provider.of<AuthProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currentUserId = auth.userModel?.uid;

    return Scaffold(
      drawer: AppDrawer(
        currentTabIndex: _currentTabIndex,
        onSelectTab: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: currentUserId != null
            ? _chatService.getUnreadChatsCountStream(currentUserId)
            : Stream.value(0),
        builder: (context, unreadSnapshot) {
          final unreadCount = unreadSnapshot.data ?? 0;
          return NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
            elevation: 4,
            indicatorColor: AppConstants.primaryColor.withOpacity(0.15),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront, color: AppConstants.primaryColor),
                label: locale.tr('browse'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.chat_bubble_rounded, color: AppConstants.primaryColor),
                ),
                label: locale.tr('chats'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2_rounded, color: AppConstants.primaryColor),
                label: locale.tr('my_listings'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded, color: AppConstants.primaryColor),
                label: locale.tr('profile'),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateListingScreen()),
                );
              },
              backgroundColor: AppConstants.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                locale.tr('sell_item'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildHeroFeatureBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getCategoryEmoji(String cat) {
    switch (cat) {
      case 'All':
        return '🔥 All';
      case 'Electronics & Phones':
        return '📱 Electronics';
      case 'Home & Furniture':
        return '🛋️ Furniture';
      case 'Fashion & Clothing':
        return '👗 Fashion';
      case 'Vehicles & Auto':
        return '🚗 Vehicles';
      case 'Property & Rentals':
        return '🏠 Rentals';
      case 'Services & Skills':
        return '💼 Services';
      case 'Books & Education':
        return '📚 Books';
      case 'Jobs & Gigs':
        return '⚡ Gigs';
      case 'Free & Donations':
        return '🎁 Free';
      default:
        return '✨ $cat';
    }
  }

  Widget _buildBrowseTab() {
    return Consumer<ListingProvider>(
      builder: (context, listingProvider, _) {
        final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
        final locale = Provider.of<LocaleProvider>(context);

        return Scaffold(
          drawer: AppDrawer(
            currentTabIndex: _currentTabIndex,
            onSelectTab: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
          ),
          appBar: AppBar(
            elevation: 0.5,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppConstants.primaryColor, size: 28),
                tooltip: 'Menu Bar (ምናሌ)',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppConstants.primaryColor, size: 22),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'All Communities',
                      style: TextStyle(
                        color: AppConstants.secondaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Consumer<LocaleProvider>(
                builder: (context, loc, _) {
                  return TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => loc.toggleLanguage(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        loc.isAmharic ? '🇪🇹 አማ' : '🇺🇸 EN',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDark = themeProvider.isCurrentDark(context);
                  return IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                      color: isDark ? Colors.amber : AppConstants.primaryColor,
                    ),
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: () => themeProvider.toggleTheme(),
                  );
                },
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final uid = auth.userModel?.uid;
                  if (uid == null) return const SizedBox.shrink();

                  return StreamBuilder<int>(
                    stream: _notificationService.getUnreadNotificationCountStream(uid),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return IconButton(
                        icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          backgroundColor: Colors.redAccent,
                          child: const Icon(Icons.notifications_outlined, color: AppConstants.primaryColor),
                        ),
                        tooltip: 'Notifications (ማሳወቂያዎች)',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              // Top Quick Menu Bar dropdown
              Builder(
                builder: (menuCtx) => PopupMenuButton<String>(
                  icon: const Icon(Icons.menu_open_rounded, color: AppConstants.primaryColor, size: 26),
                  tooltip: 'Menu Bar (ፈጣን ምናሌ)',
                  onSelected: (val) {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final user = auth.userModel;
                    switch (val) {
                      case 'drawer':
                        Scaffold.of(menuCtx).openDrawer();
                        break;
                      case 'wanted':
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemRequestsScreen()));
                        break;
                      case 'orders':
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                        break;
                      case 'favorites':
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                        break;
                      case 'verify':
                        if (user != null) {
                          showDialog(context: context, builder: (_) => VerifyIdDialog(user: user));
                        }
                        break;
                      case 'admin':
                        if (user != null && user.isAdmin) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
                        }
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'drawer',
                      child: Row(
                        children: [
                          Icon(Icons.menu_rounded, color: AppConstants.primaryColor, size: 20),
                          SizedBox(width: 10),
                          Text('Full Menu Bar (ሙሉ ምናሌ)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'wanted',
                      child: Row(
                        children: [
                          Icon(Icons.campaign_outlined, color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Text('Wanted Board (ፈልጉልኝ)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'orders',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Text('My Orders & Escrow'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'favorites',
                      child: Row(
                        children: [
                          Icon(Icons.favorite_outline, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text('Saved Favorites'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'verify',
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: Colors.green, size: 20),
                          SizedBox(width: 10),
                          Text('ID Verification'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'admin',
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                          SizedBox(width: 10),
                          Text('Super Admin Portal'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => listingProvider.refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Platform Announcement Banner if published
                StreamBuilder<Map<String, dynamic>?>(
                  stream: AdminService().getAnnouncementStream(),
                  builder: (context, snap) {
                    final announcement = snap.data;
                    if (announcement != null && announcement['isActive'] == true) {
                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  announcement['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                ),

                // Hero Marketplace Welcome Banner
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: -15,
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 110,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇪🇹', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    locale.isAmharic ? 'የኢትዮጵያ ካምፓስ ገበያ' : '#1 Ethiopian Campus Marketplace',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              locale.isAmharic ? 'በቀላሉ ይግዙና ይሽጡ 🎓' : 'Buy & Sell Across Campus 🎓',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locale.isAmharic
                                  ? 'ከተረጋገጡ ተማሪዎችና ሻጮች ጋር በቀጥታ ይደራደሩና ይገበያዩ'
                                  : 'Connect with verified students, bargain live, and meet safely.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildHeroFeatureBadge('⚡ Instant Chat'),
                                _buildHeroFeatureBadge('🤝 Live Bargain'),
                                _buildHeroFeatureBadge('🛡️ Telebirr / CBE'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          listingProvider.setSearchQuery(val);
                        },
                        decoration: InputDecoration(
                          hintText: locale.isAmharic
                              ? 'ስልኮች፣ ላፕቶፖች፣ መጽሐፍት፣ አልባሳት ይፈልጉ...'
                              : 'Search electronics, laptops, textbooks, fashion...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).hintColor.withOpacity(0.7),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.primaryColor, size: 22),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    listingProvider.setSearchQuery('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // Wanted Board Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ItemRequestsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        locale.isAmharic ? 'የሚፈልጉትን ዕቃ ይለጥፉ' : 'Wanted Board (ፈልጉልኝ)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amberAccent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'HOT 🔥',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locale.isAmharic
                                        ? 'የሚፈልጉትን ዕቃና ባጀት ይለጥፉ፡ ሻጮች ያነጋግሩዎታል'
                                        : 'Post your budget & campus peers will reach out!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Filter Chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: AppConstants.categories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = AppConstants.categories[index];
                        final isSelected = listingProvider.selectedCategory == cat;
                        return InkWell(
                          onTap: () => listingProvider.setCategory(cat),
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                    )
                                  : null,
                              color: isSelected ? null : cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.grey.shade300),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                _getCategoryEmoji(cat),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Featured VIP Deals Carousel
                StreamBuilder<List<ListingModel>>(
                  stream: MarketplaceExtensionService().getFeaturedListingsStream(),
                  builder: (context, snap) {
                    final featured = snap.data ?? [];
                    if (featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  locale.tr('featured_deals'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: featured.length,
                              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = featured[index];
                                return SizedBox(
                                  width: 155,
                                  child: ListingCard(
                                    listing: item,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ListingDetailScreen(listingId: item.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    );
                  },
                ),

                // Content (Loading, Error, Empty, or Grid)
                if (listingProvider.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingIndicator(message: 'Loading campus listings...'),
                  )
                else if (listingProvider.errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              listingProvider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => listingProvider.refresh(),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (listingProvider.listings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No Listings Found',
                      message: listingProvider.searchQuery.isNotEmpty
                          ? 'No campus items matched "${listingProvider.searchQuery}". Try different keywords.'
                          : 'No items currently available in "${listingProvider.selectedCategory}". Be the first student to post!',
                      actionLabel: 'Post Listing',
                      onAction: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateListingScreen()),
                        );
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final listing = listingProvider.listings[index];
                          return ListingCard(
                            listing: listing,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListingDetailScreen(listingId: listing.id),
                                ),
                              );
                            },
                          );
                        },
                        childCount: listingProvider.listings.length,
                      ),
                    ),
                  ),

                // Pagination Loading Spinner at bottom
                if (listingProvider.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),

                // Extra padding for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
