import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class PlatformStats {
  final int totalUsers;
  final int totalListings;
  final int activeListings;
  final int totalOrders;
  final int completedOrders;
  final int disputedOrders;
  final double totalVolumeETB;

  PlatformStats({
    required this.totalUsers,
    required this.totalListings,
    required this.activeListings,
    required this.totalOrders,
    required this.completedOrders,
    required this.disputedOrders,
    required this.totalVolumeETB,
  });
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time Platform Statistics Stream
  Stream<PlatformStats> getPlatformStatsStream() {
    return _firestore.collection('orders').snapshots().asyncMap((ordersSnap) async {
      int totalOrders = ordersSnap.docs.length;
      int completedOrders = 0;
      int disputedOrders = 0;
      double totalVolumeETB = 0.0;

      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final paymentStatus = data['paymentStatus'] as String? ?? '';
        final price = (data['listingPrice'] as num?)?.toDouble() ?? 0.0;

        if (paymentStatus == 'verified' || status == 'completed') {
          completedOrders++;
          totalVolumeETB += price;
        }
        if (paymentStatus == 'disputed') {
          disputedOrders++;
        }
      }

      int totalUsers = 0;
      try {
        final usersSnap = await _firestore.collection('users').get();
        totalUsers = usersSnap.docs.length;
      } catch (_) {}

      int totalListings = 0;
      int activeListings = 0;
      try {
        final listingsSnap = await _firestore.collection('listings').get();
        totalListings = listingsSnap.docs.length;
        for (var doc in listingsSnap.docs) {
          final data = doc.data();
          if (data['status'] == 'available') {
            activeListings++;
          }
        }
      } catch (_) {}

      return PlatformStats(
        totalUsers: totalUsers,
        totalListings: totalListings,
        activeListings: activeListings,
        totalOrders: totalOrders,
        completedOrders: completedOrders,
        disputedOrders: disputedOrders,
        totalVolumeETB: totalVolumeETB,
      );
    });
  }

  // Stream All Users
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // Update User Role (e.g. 'super_admin', 'admin', 'user')
  Future<void> setUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
    });
  }

  // Ban or Unban User
  Future<void> toggleBanUser(String uid, bool isBanned) async {
    await _firestore.collection('users').doc(uid).update({
      'isBanned': isBanned,
    });
  }

  // Verify Seller Checkmark
  Future<void> toggleVerifySeller(String uid, bool isVerified) async {
    await _firestore.collection('users').doc(uid).update({
      'isVerifiedSeller': isVerified,
    });
  }

  // Stream All Listings for Moderation
  Stream<List<ListingModel>> getAllListingsStream() {
    return _firestore
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ListingModel.fromFirestore(doc)).toList());
  }

  // Admin Delete Listing
  Future<void> deleteListingAdmin(String listingId) async {
    await _firestore.collection('listings').doc(listingId).delete();
  }

  // Change Listing Status ('available', 'hidden', 'sold')
  Future<void> updateListingStatus(String listingId, String status) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': status,
    });
  }

  // Stream All Orders
  Stream<List<OrderModel>> getAllOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // Resolve Dispute
  Future<void> resolveDisputeAdmin({
    required String orderId,
    required String action, // 'approve_payment' or 'cancel_order'
    required String adminNote,
  }) async {
    if (action == 'approve_payment') {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'verified',
        'status': 'accepted',
        'verifiedAt': Timestamp.now(),
        'adminDisputeNote': adminNote,
        'updatedAt': Timestamp.now(),
      });
    } else {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'adminDisputeNote': adminNote,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  // Post Platform Announcement
  Future<void> setAnnouncement(String title, String message, bool isActive) async {
    await _firestore.collection('settings').doc('announcement').set({
      'title': title,
      'message': message,
      'isActive': isActive,
      'updatedAt': Timestamp.now(),
    });
  }

  // Get Announcement Stream
  Stream<Map<String, dynamic>?> getAnnouncementStream() {
    return _firestore.collection('settings').doc('announcement').snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }
}
