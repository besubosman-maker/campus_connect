import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../services/listing_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import 'create_listing_screen.dart';
import 'boost_listing_dialog.dart';
import 'listing_detail_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  final ListingService _listingService = ListingService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to manage your listings')),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('My Listings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppConstants.primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Available'),
            Tab(text: 'Sold'),
          ],
        ),
      ),
      body: StreamBuilder<List<ListingModel>>(
        stream: _listingService.getUserListingsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading your listings...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final allListings = snapshot.data ?? [];
          final availableListings =
              allListings.where((l) => l.isAvailable).toList();
          final soldListings = allListings.where((l) => l.isSold).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListingsList(allListings, currencyFormat, 'No listings posted yet.'),
              _buildListingsList(availableListings, currencyFormat, 'No active available listings.'),
              _buildListingsList(soldListings, currencyFormat, 'No items marked as sold yet.'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListingsList(
    List<ListingModel> items,
    NumberFormat currencyFormat,
    String emptyMessage,
  ) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Items Found',
        message: emptyMessage,
        actionLabel: 'Post an Item',
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateListingScreen(),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final listing = items[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListingDetailScreen(listingId: listing.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: listing.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: listing.images.first,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: listing.isAvailable
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                listing.status.toUpperCase(),
                                style: TextStyle(
                                  color: listing.isAvailable ? Colors.green[800] : Colors.red[800],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (listing.isBoostedActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'VIP BOOSTED 🚀',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              listing.category,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(listing.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions menu
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'boost') {
                        showDialog(
                          context: context,
                          builder: (ctx) => BoostListingDialog(listing: listing),
                        );
                      } else if (val == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateListingScreen(existingListing: listing),
                          ),
                        );
                      } else if (val == 'status') {
                        final newStatus = listing.isAvailable ? 'sold' : 'available';
                        await _listingService.updateListingStatus(listing.id, newStatus);
                      } else if (val == 'delete') {
                        _confirmDelete(listing);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'boost',
                        child: Row(
                          children: [
                            Icon(Icons.rocket_launch_rounded, size: 18, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Text('Boost Listing 🚀', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(
                              listing.isAvailable
                                  ? Icons.check_circle_outline
                                  : Icons.refresh_rounded,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(listing.isAvailable ? 'Mark as Sold' : 'Mark as Available'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(ListingModel listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Are you sure you want to delete "${listing.title}"?'),
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

    if (confirm == true && mounted) {
      await Provider.of<ListingProvider>(context, listen: false)
          .deleteListing(listing.id, listing.images);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted')),
        );
      }
    }
  }
}
