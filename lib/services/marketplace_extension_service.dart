import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listing_model.dart';

class MarketplaceExtensionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Toggle Favorite Listing
  Future<bool> toggleFavorite({
    required String uid,
    required String listingId,
    required bool isCurrentlyFavorite,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      if (isCurrentlyFavorite) {
        await userRef.update({
          'favorites': FieldValue.arrayRemove([listingId]),
        });
        return false;
      } else {
        await userRef.update({
          'favorites': FieldValue.arrayUnion([listingId]),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return isCurrentlyFavorite;
    }
  }

  // Stream User's Favorite Listings
  Stream<List<ListingModel>> getFavoriteListingsStream(List<String> favoriteIds) {
    if (favoriteIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore whereIn supports up to 10-30 ids at once
    final chunk = favoriteIds.take(20).toList();
    return _firestore
        .collection('listings')
        .where(FieldPath.documentId, whereIn: chunk)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ListingModel.fromFirestore(d)).toList());
  }

  // Stream Featured / Boosted Listings for VIP Carousel
  Stream<List<ListingModel>> getFeaturedListingsStream() {
    return _firestore
        .collection('listings')
        .where('isFeatured', isEqualTo: true)
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .map((d) => ListingModel.fromFirestore(d))
              .where((item) => item.featuredUntil == null || item.featuredUntil!.isAfter(now))
              .toList();
        });
  }

  // Boost Listing (Paid Featured Promotion)
  Future<void> boostListing({
    required String listingId,
    required int days,
    required String paymentMethod,
  }) async {
    final expiry = DateTime.now().add(Duration(days: days));
    await _firestore.collection('listings').doc(listingId).update({
      'isFeatured': true,
      'featuredUntil': Timestamp.fromDate(expiry),
      'boostPlanDays': days,
      'boostPaymentMethod': paymentMethod,
    });
  }

  // Submit Kebele ID / Student ID for Verification
  Future<void> submitIdVerification({
    required String uid,
    required String idDocumentUrl,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'idVerificationStatus': 'pending',
      'idDocumentUrl': idDocumentUrl,
      'idSubmittedAt': Timestamp.now(),
    });
  }

  // Launch Direct Phone Call
  Future<void> launchPhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch phone dialer for: $phoneNumber');
    }
  }

  // Launch Telegram Chat
  Future<void> launchTelegram(String username) async {
    final cleanUser = username.replaceAll('@', '').trim();
    final Uri uri = Uri.parse('https://t.me/$cleanUser');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch telegram for: $username');
    }
  }
}
