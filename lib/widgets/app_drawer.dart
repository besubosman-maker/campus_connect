import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/listing/create_listing_screen.dart';
import '../screens/listing/favorites_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/order/orders_screen.dart';
import '../screens/profile/verify_id_dialog.dart';
import '../screens/requests/item_requests_screen.dart';

class AppDrawer extends StatelessWidget {
  final int? currentTabIndex;
  final ValueChanged<int>? onSelectTab;

  const AppDrawer({
    super.key,
    this.currentTabIndex,
    this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isCurrentDark(context);
    final user = auth.userModel;

    return Drawer(
      child: Column(
        children: [
          // 1. User Profile Header Card
          _buildDrawerHeader(context, user, isDark),

          // 2. Navigation Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // --- SECTION: MARKETPLACE ---
                _buildSectionHeader('MARKETPLACE & CAMPUS'),
                _buildDrawerItem(
                  icon: Icons.storefront_rounded,
                  iconColor: AppConstants.primaryColor,
                  title: locale.tr('browse'),
                  subtitle: 'Explore campus textbooks, tech & dorm items',
                  isSelected: currentTabIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab?.call(0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.campaign_rounded,
                  iconColor: Colors.orange.shade800,
                  title: 'Wanted Board (ፈልጉልኝ)',
                  subtitle: 'Post or find item requests on campus',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ItemRequestsScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  title: locale.tr('sell_item'),
                  subtitle: 'List an item for campus peers',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.redAccent,
                  title: locale.tr('saved_favorites'),
                  subtitle: 'Bookmarks & saved deals',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),

                const Divider(height: 20),

                // --- SECTION: MY ACCOUNT & ORDERS ---
                _buildSectionHeader('MY ACTIVITY & TRADES'),
                _buildDrawerItem(
                  icon: Icons.receipt_long_rounded,
                  iconColor: Colors.blue.shade700,
                  title: 'My Orders & Escrow',
                  subtitle: 'Track purchases, verification & delivery',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.chat_bubble_rounded,
                  iconColor: Colors.teal.shade700,
                  title: locale.tr('chats'),
                  subtitle: 'Direct messages & bargain negotiations',
                  isSelected: currentTabIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab?.call(1);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2_rounded,
                  iconColor: Colors.deepPurple,
                  title: locale.tr('my_listings'),
                  subtitle: 'Manage active, sold and boosted items',
                  isSelected: currentTabIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab?.call(2);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_rounded,
                  iconColor: Colors.amber.shade800,
                  title: 'Notifications',
                  subtitle: 'Alerts, bargain offers & system updates',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  iconColor: AppConstants.primaryColor,
                  title: locale.tr('profile'),
                  subtitle: 'Account details, ratings & student info',
                  isSelected: currentTabIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab?.call(3);
                  },
                ),

                const Divider(height: 20),

                // --- SECTION: TRUST & SAFETY ---
                _buildSectionHeader('TRUST & SECURITY'),
                _buildDrawerItem(
                  icon: Icons.verified_user_rounded,
                  iconColor: user?.isIdVerified == true ? Colors.green : Colors.orange.shade700,
                  title: 'Student ID Verification',
                  subtitle: user?.isIdVerified == true
                      ? 'Verified Student 🛡️'
                      : (user?.idVerificationStatus == 'pending'
                          ? 'Verification Under Review ⏳'
                          : 'Upload Kebele/Student ID'),
                  onTap: () {
                    Navigator.pop(context);
                    if (user != null) {
                      showDialog(
                        context: context,
                        builder: (_) => VerifyIdDialog(user: user),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.health_and_safety_outlined,
                  iconColor: Colors.teal,
                  title: 'Campus Safety Guidelines',
                  subtitle: 'Meetup spots, verification & scam safety',
                  onTap: () {
                    Navigator.pop(context);
                    _showSafetyGuidelinesDialog(context);
                  },
                ),

                const Divider(height: 20),

                // --- SECTION: PREFERENCES & SYSTEM ---
                _buildSectionHeader('PREFERENCES & SYSTEM'),
                SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? Colors.amber : AppConstants.primaryColor,
                  ),
                  title: const Text(
                    'Dark Mode (ጨለማ ገጽታ)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  value: isDark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: AppConstants.primaryColor),
                  title: const Text(
                    'Language (ቋንቋ)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    locale.isAmharic ? 'አማርኛ (Amharic)' : 'English (United States)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      locale.isAmharic ? '🇪🇹 አማ' : '🇺🇸 EN',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () => locale.toggleLanguage(),
                ),

                // --- SECTION: SUPER ADMIN PORTAL ---
                _buildDrawerItem(
                  icon: Icons.shield_rounded,
                  iconColor: Colors.amber.shade800,
                  title: 'Super Admin Portal',
                  subtitle: 'Platform governance, moderation & escrow',
                  onTap: () {
                    Navigator.pop(context);
                    if (user != null && user.isAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                      );
                    }
                  },
                ),

                const Divider(height: 20),

                // --- SIGN OUT ---
                if (user != null)
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.redAccent,
                    title: locale.tr('logout'),
                    subtitle: 'Sign out of this campus device',
                    onTap: () {
                      Navigator.pop(context);
                      _showSignOutDialog(context, auth);
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 3. Footer Branding
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CampusConnect v1.0.0 • Ethiopian Campuses 🇪🇹',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, UserModel? user, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryColor.withOpacity(0.9),
            AppConstants.secondaryColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl!)
                    : null,
                child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                    ? Text(
                        (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user?.isIdVerified == true ? Icons.verified_rounded : Icons.shield_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.isIdVerified == true
                          ? 'Verified'
                          : (user?.idVerificationStatus == 'pending' ? 'Pending' : 'Unverified'),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.name ?? 'Campus Student',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user?.email ?? 'student@campus.edu.et',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Addis Ababa University • Main Campus 🇪🇹',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppConstants.primaryColor.withOpacity(0.08),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? AppConstants.primaryColor : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showSafetyGuidelinesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text('Campus Safety (የደህንነት ደንቦች)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Protecting students on Ethiopian university campuses:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 10),
              Text('1. 📍 Always meet in public campus locations (e.g. University Library, Student Union, Main Gate).'),
              SizedBox(height: 8),
              Text('2. 🔍 Inspect physical items (textbooks, laptops, electronics) thoroughly before verifying release of escrow payment.'),
              SizedBox(height: 8),
              Text('3. 💳 Use in-app Telebirr, CBE, or Chapa payment verification so funds are protected.'),
              SizedBox(height: 8),
              Text('4. 🛡️ Check if the seller has a verified student badge before agreeing to large transactions.'),
              SizedBox(height: 8),
              Text('5. 🚩 Use the flag icon in chat or on listings to report any suspicious activity immediately.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood (ተረድቻለሁ)'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out (ውጣ)?'),
        content: const Text('Are you sure you want to sign out from CampusConnect on this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
