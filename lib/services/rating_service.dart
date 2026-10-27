import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rating_model.dart';

class RatingService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference get _ratingsRef => _firestore.collection('ratings');
  CollectionReference get _usersRef => _firestore.collection('users');

  /// Submit a rating for a seller and atomically update the seller's average rating and count.
  Future<void> submitRating({
    required String fromUserId,
    required String toUserId,
    required String listingId,
    required double stars,
    required String comment,
  }) async {
    final ratingDocRef = _ratingsRef.doc();
    final userDocRef = _usersRef.doc(toUserId);

    await _firestore.runTransaction((transaction) async {
      // Read current seller profile
      final userSnapshot = await transaction.get(userDocRef);
      if (!userSnapshot.exists) {
        throw Exception('Seller profile not found');
      }

      final userData = userSnapshot.data() as Map<String, dynamic>? ?? {};
      final currentAvg = (userData['rating'] as num?)?.toDouble() ?? 0.0;
      final currentCount = (userData['ratingCount'] as num?)?.toInt() ?? 0;

      // Calculate new weighted average
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + stars) / newCount;

      // Round to 1 decimal place
      final roundedAvg = (newAvg * 10).round() / 10.0;

      // Write rating record
      final ratingData = {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'listingId': listingId,
        'stars': stars,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(ratingDocRef, ratingData);

      // Update seller's aggregate rating
      transaction.update(userDocRef, {
        'rating': roundedAvg,
        'ratingCount': newCount,
      });
    });
  }

  /// Check if the user has already rated a specific listing.
  Future<bool> hasUserRatedListing({
    required String fromUserId,
    required String listingId,
  }) async {
    try {
      final query = await _ratingsRef
          .where('fromUserId', isEqualTo: fromUserId)
          .where('listingId', isEqualTo: listingId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user rating: $e');
      return false;
    }
  }

  /// Stream of ratings received by a specific seller.
  Stream<List<RatingModel>> getUserRatingsStream(String userId) {
    return _ratingsRef
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
