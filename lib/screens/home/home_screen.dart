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

  Widget _buildBrowseTab() {
    return Consumer<ListingProvider>(
      builder: (context, listingProvider, _) {
        final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
        final locale = Provider.of<LocaleProvider>(context);

        return Scaffold(
          appBar: AppBar(
            elevation: 0.5,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppConstants.primaryColor, size: 24),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
              IconButton(
                icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                tooltip: 'Saved Favorites',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                  );
                },
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final user = auth.userModel;
                  if (user != null && user.isAdmin) {
                    return IconButton(
                      icon: const Icon(Icons.shield_rounded, color: Colors.amber),
                      tooltip: 'Super Admin Dashboard',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              IconButton(
                icon: const Icon(Icons.campaign_outlined, color: AppConstants.primaryColor),
                tooltip: 'Wanted Board (ፈልጉልኝ)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ItemRequestsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined, color: AppConstants.primaryColor),
                tooltip: 'My Orders & Sales',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OrdersScreen()),
                  );
                },
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

                // Search Bar Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          listingProvider.setSearchQuery(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search electronics, home goods, vehicles, fashion...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppConstants.primaryColor.withOpacity(0.08),
                              Colors.purple.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppConstants.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.campaign, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locale.isAmharic ? 'የሚፈልጉትን ዕቃ ይለጥፉ (ፈልጉልኝ)' : 'Looking for an item? Wanted Board',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    locale.isAmharic ? 'ተማሪዎችና ሻጮች ባጀትዎ ላይ ሆነው ያነጋግሩዎታል' : 'Post your budget & campus peers will reach out!',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppConstants.primaryColor),
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
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppConstants.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppConstants.primaryColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              listingProvider.setCategory(cat);
                            }
                          },
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
