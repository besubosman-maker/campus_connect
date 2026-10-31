import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../services/admin_service.dart';
import '../../services/report_service.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/rating_stars.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  final ReportService _reportService = ReportService();

  // Search controllers
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _listingSearchController = TextEditingController();

  String _userSearchQuery = '';
  String _listingSearchQuery = '';
  String _orderFilter = 'all'; // 'all', 'disputed', 'verified', 'pending'
  String _reportFilter = 'pending'; // 'pending', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _userSearchController.addListener(() {
      setState(() {
        _userSearchQuery = _userSearchController.text.trim().toLowerCase();
      });
    });
    _listingSearchController.addListener(() {
      setState(() {
        _listingSearchQuery = _listingSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _listingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.shade700.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Super Admin Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Platform Governance & Moderation',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppConstants.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.gavel_rounded), text: 'Disputes & Orders'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'Reports & Flags'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Listings'),
            Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Users & Roles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isDark),
          _buildDisputesOrdersTab(isDark),
          _buildReportsTab(isDark),
          _buildListingsTab(isDark),
          _buildUsersTab(isDark),
        ],
      ),
    );
  }

  // ================= TAB 1: OVERVIEW & STATS =================
  Widget _buildOverviewTab(bool isDark) {
    return StreamBuilder<PlatformStats>(
      stream: _adminService.getPlatformStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ??
            PlatformStats(
              totalUsers: 0,
              totalListings: 0,
              activeListings: 0,
              totalOrders: 0,
              completedOrders: 0,
              disputedOrders: 0,
              totalVolumeETB: 0.0,
            );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Urgent Disputes Alert Banner if any
              if (stats.disputedOrders > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stats.disputedOrders} Payment Dispute(s) Require Attention!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                            Text(
                              'Sellers and buyers need administrative arbitration.',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Grid of Key Platform Metrics
              const Text(
                'Key Marketplace Metrics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _buildMetricCard(
                    title: 'Gross Volume',
                    value: '${AppConstants.currencySymbol}${NumberFormat('#,##0').format(stats.totalVolumeETB)}',
                    subtitle: 'Completed trade volume',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF059669),
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Orders Processed',
                    value: '${stats.totalOrders}',
                    subtitle: '${stats.completedOrders} completed',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF1E3A8A),
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Active Listings',
                    value: '${stats.activeListings}',
                    subtitle: '${stats.totalListings} total items listed',
                    icon: Icons.storefront_rounded,
                    color: Colors.amber.shade800,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Registered Members',
                    value: '${stats.totalUsers}',
                    subtitle: 'Across all Ethiopian cities',
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // System Status Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.health_and_safety_outlined, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Platform Integrations Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildStatusRow('Chapa Ethiopian Payment Gateway', 'Active (Telebirr/CBE/Cards)', true),
                      const Divider(height: 16),
                      _buildStatusRow('Firebase Cloud Database & Auth', 'Connected & Operational', true),
                      const Divider(height: 16),
                      _buildStatusRow('Cloud Image Storage', 'Operational', true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Super Admin Quick Controls Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Administrative Quick Actions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Colors.blue),
                        ),
                        title: const Text('Broadcast Platform Announcement'),
                        subtitle: const Text('Show a banner alert to all active app users'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAnnouncementDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isOk) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.error_rounded,
              color: isOk ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOk ? Colors.green.shade700 : Colors.red,
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: DISPUTES & ORDERS =================
  Widget _buildDisputesOrdersTab(bool isDark) {
    return Column(
      children: [
        // Filter row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Orders'),
                const SizedBox(width: 8),
                _buildFilterChip('disputed', 'Disputed Only ⚠️'),
                const SizedBox(width: 8),
                _buildFilterChip('verified', 'Verified Paid'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Orders list
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _adminService.getAllOrdersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = snapshot.data ?? [];

              if (_orderFilter == 'disputed') {
                orders = orders.where((o) => o.paymentStatus == 'disputed').toList();
              } else if (_orderFilter == 'verified') {
                orders = orders.where((o) => o.paymentStatus == 'verified').toList();
              } else if (_orderFilter == 'pending') {
                orders = orders.where((o) => o.status == 'pending').toList();
              }

              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      Text(
                        'No orders found matching "$_orderFilter"',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final isDisputed = order.paymentStatus == 'disputed';

                  return Card(
                    elevation: isDisputed ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDisputed ? Colors.red.shade400 : Colors.transparent,
                        width: isDisputed ? 1.5 : 0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order.listingTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDisputed
                                      ? Colors.red.shade100
                                      : order.paymentStatus == 'verified'
                                          ? Colors.green.shade100
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isDisputed
                                      ? 'DISPUTED'
                                      : order.paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDisputed
                                        ? Colors.red.shade900
                                        : order.paymentStatus == 'verified'
                                            ? Colors.green.shade900
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Amount & Details
                          Text(
                            'Price: ${AppConstants.currencySymbol}${order.listingPrice.toStringAsFixed(2)}  •  Method: ${order.paymentMethod}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Buyer: ${order.buyerName} (${order.buyerEmail})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Seller: ${order.sellerName} (${order.sellerEmail})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (order.transactionRef != null && order.transactionRef!.isNotEmpty)
                            Text(
                              'Tx Ref: ${order.transactionRef}',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                            ),

                          // Disputed Notice
                          if (isDisputed) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.report_problem, color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Seller Report: ${order.disputeReason ?? "Payment dispute reported"}',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Admin Dispute Arbitration Actions
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle_outline, size: 16),
                                    label: const Text('Force Verify', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _handleAdminResolution(order.id, 'approve_payment'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                    label: const Text('Cancel Order', style: TextStyle(fontSize: 12, color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    onPressed: () => _handleAdminResolution(order.id, 'cancel_order'),
                                  ),
                                ),
                              ],
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
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _orderFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _orderFilter = filterKey;
          });
        }
      },
      selectedColor: AppConstants.primaryColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppConstants.primaryColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Future<void> _handleAdminResolution(String orderId, String action) async {
    final noteController = TextEditingController(
      text: action == 'approve_payment'
          ? 'Approved by Super Admin after proof verification'
          : 'Cancelled by Super Admin due to unverified dispute',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve_payment' ? 'Force Verify Payment' : 'Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action == 'approve_payment'
                  ? 'This will override the dispute and mark the order as officially verified.'
                  : 'This will cancel the order and instruct the buyer and seller accordingly.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Arbitration Note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve_payment' ? Colors.green : Colors.red,
            ),
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminService.resolveDisputeAdmin(
        orderId: orderId,
        action: action,
        adminNote: noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute resolved successfully!')),
        );
      }
    }
  }

  // ================= TAB: REPORTS & CONTENT MODERATION =================
  Widget _buildReportsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Pending Moderation'),
                selected: _reportFilter == 'pending',
                onSelected: (val) {
                  setState(() {
                    _reportFilter = val ? 'pending' : 'all';
                  });
                },
                selectedColor: Colors.amber.shade100,
                checkmarkColor: Colors.amber.shade900,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('All Reports'),
                selected: _reportFilter == 'all',
                onSelected: (val) {
                  setState(() {
                    _reportFilter = val ? 'all' : 'pending';
                  });
                },
                selectedColor: Colors.blue.shade100,
                checkmarkColor: Colors.blue.shade900,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReportModel>>(
            stream: _reportService.getReportsStream(
              status: _reportFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 64, color: Colors.green.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Flagged Reports',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _reportFilter == 'pending'
                            ? 'All student and marketplace listings are clean.'
                            : 'No reports found in history.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final isPending = report.status == 'pending';
                  final isListing = report.targetType == 'listing';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isPending ? Colors.redAccent.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isListing ? Colors.deepPurple.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isListing ? Colors.deepPurple.shade200 : Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isListing ? Icons.inventory_2_outlined : Icons.person_outline,
                                      size: 14,
                                      color: isListing ? Colors.deepPurple : Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isListing ? 'LISTING' : 'USER',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isListing ? Colors.deepPurple : Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPending ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  report.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPending ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMM dd, yyyy').format(report.createdAt),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            report.targetTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    report.reason,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (report.details.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Details: "${report.details}"',
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Reported by: ${report.reporterName} (ID: ${report.reporterId.length > 8 ? report.reporterId.substring(0, 8) : report.reporterId})',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isPending) ...[
                                TextButton.icon(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                  label: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                                  onPressed: () async {
                                    await _reportService.updateReportStatus(report.id, 'dismissed');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Report dismissed')),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                if (isListing)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    label: const Text('Delete Item', style: TextStyle(color: Colors.red)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Reported Listing?'),
                                          content: Text('Remove "${report.targetTitle}" from marketplace?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _adminService.deleteListingAdmin(report.targetId);
                                        await _reportService.updateReportStatus(report.id, 'resolved');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Listing deleted and report resolved')),
                                          );
                                        }
                                      }
                                    },
                                  )
                                else
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.block, size: 16, color: Colors.red),
                                    label: const Text('Ban User', style: TextStyle(color: Colors.red)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Ban Reported User?'),
                                          content: Text('Suspend "${report.targetTitle}" from platform?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Ban'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _adminService.toggleBanUser(report.targetId, true);
                                        await _reportService.updateReportStatus(report.id, 'resolved');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('User banned and report resolved')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Resolve'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () async {
                                    await _reportService.updateReportStatus(report.id, 'resolved');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Report marked as resolved')),
                                      );
                                    }
                                  },
                                ),
                              ] else ...[
                                Chip(
                                  label: Text('Marked ${report.status}'),
                                  backgroundColor: report.status == 'resolved' ? Colors.green.shade50 : Colors.grey.shade200,
                                  labelStyle: TextStyle(
                                    color: report.status == 'resolved' ? Colors.green.shade800 : Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    );
  }

  // ================= TAB 3: LISTINGS MODERATION =================
  Widget _buildListingsTab(bool isDark) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _listingSearchController,
            decoration: InputDecoration(
              hintText: 'Search listings by title...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _listingSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _listingSearchController.clear(),
                    )
                  : null,
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<ListingModel>>(
            stream: _adminService.getAllListingsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var listings = snapshot.data ?? [];
              if (_listingSearchQuery.isNotEmpty) {
                listings = listings
                    .where((l) =>
                        l.title.toLowerCase().contains(_listingSearchQuery) ||
                        l.category.toLowerCase().contains(_listingSearchQuery))
                    .toList();
              }

              if (listings.isEmpty) {
                return const Center(child: Text('No listings found.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: listings.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final listing = listings[index];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 54,
                          height: 54,
                          color: Colors.grey.shade200,
                          child: listing.images.isNotEmpty
                              ? AppImageHelper.buildImage(
                                  imageUrl: listing.images.first,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      title: Text(
                        listing.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${AppConstants.currencySymbol}${listing.price.toStringAsFixed(2)}  •  ${listing.category}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          Text(
                            'Status: ${listing.status}  •  ${DateFormat('MMM d, y').format(listing.createdAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (val) async {
                          if (val == 'delete') {
                            final del = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Listing?'),
                                content: Text('Remove "${listing.title}" from the marketplace?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (del == true) {
                              await _adminService.deleteListingAdmin(listing.id);
                            }
                          } else if (val == 'toggle_status') {
                            final newStatus = listing.status == 'available' ? 'hidden' : 'available';
                            await _adminService.updateListingStatus(listing.id, newStatus);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Text(listing.status == 'available' ? 'Hide Listing' : 'Make Available'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Listing', style: TextStyle(color: Colors.red)),
                          ),
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
    );
  }

  // ================= TAB 4: USERS & ROLES =================
  Widget _buildUsersTab(bool isDark) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: 'Search members by name or email...',
              prefixIcon: const Icon(Icons.person_search),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _userSearchController.clear(),
                    )
                  : null,
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _adminService.getAllUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data ?? [];
              if (_userSearchQuery.isNotEmpty) {
                users = users
                    .where((u) =>
                        u.name.toLowerCase().contains(_userSearchQuery) ||
                        u.email.toLowerCase().contains(_userSearchQuery))
                    .toList();
              }

              if (users.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSuper = user.isSuperAdmin;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                        backgroundImage: user.photoUrl != null
                            ? AppImageHelper.getImageProvider(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U')
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerifiedSeller) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 16, color: Colors.blue),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSuper
                                      ? Colors.amber.shade100
                                      : user.role == 'admin'
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSuper ? 'SUPER ADMIN' : user.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSuper
                                        ? Colors.amber.shade900
                                        : user.role == 'admin'
                                            ? Colors.blue.shade900
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                              if (user.isBanned) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'BANNED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                              if (user.idVerificationStatus == 'pending') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ID PENDING',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              RatingStars(rating: user.rating, starSize: 12),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (val) async {
                          if (val == 'verify_id') {
                            await _adminService.verifyUserIdentity(user.uid, true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ID Verified for ${user.name}! Green badge awarded.')),
                              );
                            }
                          } else if (val == 'reject_id') {
                            await _adminService.verifyUserIdentity(user.uid, false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ID submission rejected for ${user.name}.')),
                              );
                            }
                          } else if (val == 'view_id_doc') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('${user.name} - ID Document'),
                                content: AppImageHelper.buildImage(
                                  imageUrl: user.idDocumentUrl!,
                                  height: 260,
                                  width: 320,
                                  fit: BoxFit.contain,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          } else if (val == 'toggle_ban') {
                            await _adminService.toggleBanUser(user.uid, !user.isBanned);
                          } else if (val == 'toggle_verify') {
                            await _adminService.toggleVerifySeller(user.uid, !user.isVerifiedSeller);
                          } else if (val == 'make_admin') {
                            await _adminService.setUserRole(user.uid, 'admin');
                          } else if (val == 'make_super_admin') {
                            await _adminService.setUserRole(user.uid, 'super_admin');
                          } else if (val == 'remove_admin') {
                            await _adminService.setUserRole(user.uid, 'user');
                          }
                        },
                        itemBuilder: (context) => [
                          if (user.idDocumentUrl != null && user.idDocumentUrl!.isNotEmpty) ...[
                            const PopupMenuItem(
                              value: 'view_id_doc',
                              child: Row(
                                children: [
                                  Icon(Icons.image_search_rounded, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Inspect ID Document', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                          if (user.idVerificationStatus == 'pending') ...[
                            const PopupMenuItem(
                              value: 'verify_id',
                              child: Text('Approve Kebele / Student ID ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                            const PopupMenuItem(
                              value: 'reject_id',
                              child: Text('Reject ID Submission ✗', style: TextStyle(color: Colors.red)),
                            ),
                            const PopupMenuDivider(),
                          ],
                          PopupMenuItem(
                            value: 'toggle_verify',
                            child: Text(user.isVerifiedSeller ? 'Revoke Verified Badge' : 'Grant Verified Badge'),
                          ),
                          PopupMenuItem(
                            value: 'toggle_ban',
                            child: Text(user.isBanned ? 'Unban Member' : 'Ban Member',
                                style: TextStyle(color: user.isBanned ? Colors.green : Colors.red)),
                          ),
                          if (user.role != 'admin' && !isSuper)
                            const PopupMenuItem(
                              value: 'make_admin',
                              child: Text('Promote to Admin'),
                            ),
                          if (!isSuper)
                            const PopupMenuItem(
                              value: 'make_super_admin',
                              child: Text('Promote to Super Admin'),
                            ),
                          if (user.role != 'user')
                            const PopupMenuItem(
                              value: 'remove_admin',
                              child: Text('Demote to Regular User'),
                            ),
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
    );
  }

  // ================= ANNOUNCEMENT DIALOG =================
  void _showAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'CampusConnect Announcement');
    final messageController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Broadcast Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Announcement Message',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Welcome to the new Ethiopian community marketplace! 🇪🇹',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active Banner'),
                value: isActive,
                onChanged: (val) {
                  setDialogState(() {
                    isActive = val;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.trim().isNotEmpty) {
                  await _adminService.setAnnouncement(
                    titleController.text.trim(),
                    messageController.text.trim(),
                    isActive,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Publish Banner'),
            ),
          ],
        ),
      ),
    );
  }
}
