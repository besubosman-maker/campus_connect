import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/rating_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/rating_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/rating_stars.dart';
import '../listing/my_listings_screen.dart';
import '../order/orders_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;
    final ratingService = RatingService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view profile')),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                    backgroundImage: user.photoUrl != null
                        ? AppImageHelper.getImageProvider(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? const Icon(Icons.person, size: 48, color: AppConstants.primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Rating Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: RatingStars(
                      rating: user.rating,
                      count: user.ratingCount,
                      starSize: 18,
                    ),
                  ),
                  if ((user.telebirrNumber != null && user.telebirrNumber!.isNotEmpty) ||
                      (user.cbeAccount != null && user.cbeAccount!.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (user.telebirrNumber != null && user.telebirrNumber!.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.phone_android, size: 16, color: Colors.blue),
                            label: Text('Telebirr: ${user.telebirrNumber}', style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (user.cbeAccount != null && user.cbeAccount!.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.account_balance, size: 16, color: Colors.purple),
                            label: Text('CBE: ${user.cbeAccount}', style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.purple.shade50,
                            side: BorderSide(color: Colors.purple.shade200),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Campus member since ${DateFormat('MMMM y').format(user.joinedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Menu Options Card
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined, color: AppConstants.primaryColor),
                    title: const Text('My Items for Sale'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyListingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: AppConstants.primaryColor),
                    title: const Text('Campus Orders (Purchases & Sales)'),
                    subtitle: const Text('Track active orders & meetups', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrdersScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: AppConstants.primaryColor),
                    title: const Text('Edit Account Info'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reviews and Feedback Received
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seller Reputation & Feedback (${user.ratingCount})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<RatingModel>>(
              stream: ratingService.getUserRatingsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final ratings = snapshot.data ?? [];
                if (ratings.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 36, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No ratings yet',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete trades and buyers will leave reviews here to build your trusted reputation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ratings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rating = ratings[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RatingStars(rating: rating.stars, starSize: 15),
                              Text(
                                DateFormat('MMM d, y').format(rating.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                          if (rating.comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '"${rating.comment}"',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to sign out of CampusConnect?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            auth.signOut();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
