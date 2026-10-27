import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import 'email_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ordersRef => _firestore.collection('orders');
  CollectionReference get _listingsRef => _firestore.collection('listings');

  /// Creates a new campus order when a student buys an item.
  Future<OrderModel> createOrder({
    required String listingId,
    required String listingTitle,
    required double listingPrice,
    String? listingImage,
    required String sellerId,
    required String sellerName,
    required String sellerEmail,
    required String buyerId,
    required String buyerName,
    required String buyerEmail,
    required String meetupLocation,
    required String meetupTime,
    String? buyerNote,
    String paymentMethod = 'Telebirr (ቴሌብር)',
    String? paymentDetails,
  }) async {
    if (buyerId == sellerId) {
      throw Exception('You cannot purchase your own listing.');
    }

    final docRef = _ordersRef.doc();
    final now = DateTime.now();

    final order = OrderModel(
      id: docRef.id,
      listingId: listingId,
      listingTitle: listingTitle,
      listingPrice: listingPrice,
      listingImage: listingImage,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerEmail: sellerEmail,
      buyerId: buyerId,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      meetupLocation: meetupLocation,
      meetupTime: meetupTime,
      buyerNote: buyerNote,
      paymentMethod: paymentMethod,
      paymentDetails: paymentDetails,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    // Save order in Firestore
    await docRef.set(order.toMap());

    // Send automated email alert to seller's real inbox
    if (sellerEmail.isNotEmpty) {
      EmailService.sendAutomatedEmailNotification(
        toEmail: sellerEmail,
        toName: sellerName,
        fromName: buyerName,
        subject: '[CampusConnect] New Order: $listingTitle from $buyerName',
        message: 'Hi $sellerName,\n\n'
            'Student $buyerName wants to buy "$listingTitle" for \$${listingPrice.toStringAsFixed(2)}.\n\n'
            'Proposed Meetup Location: $meetupLocation\n'
            'Proposed Time: $meetupTime\n'
            'Note: ${buyerNote ?? "None"}\n\n'
            'Open the CampusConnect app on your phone to accept the order!',
      ).catchError((e) {
        debugPrint('Email alert notice: $e');
        return false;
      });
    }

    return order;
  }

  /// Real-time stream of orders placed by the current student (My Purchases).
  Stream<List<OrderModel>> getBuyerOrdersStream(String buyerId) {
    return _ordersRef
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Real-time stream of incoming orders for items the student is selling (My Sales).
  Stream<List<OrderModel>> getSellerOrdersStream(String sellerId) {
    return _ordersRef
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Seller accepts the student order.
  Future<void> acceptOrder(OrderModel order) async {
    await _ordersRef.doc(order.id).update({
      'status': 'accepted',
      'updatedAt': Timestamp.now(),
    });

    // Notify buyer via email
    if (order.buyerEmail.isNotEmpty) {
      EmailService.sendAutomatedEmailNotification(
        toEmail: order.buyerEmail,
        toName: order.buyerName,
        fromName: order.sellerName,
        subject: '[CampusConnect] Order Accepted: ${order.listingTitle}',
        message: 'Hi ${order.buyerName},\n\n'
            'Great news! ${order.sellerName} accepted your order for "${order.listingTitle}".\n\n'
            'Meetup Location: ${order.meetupLocation}\n'
            'Meetup Time: ${order.meetupTime}\n\n'
            'See you on campus!',
      ).catchError((e) => false);
    }
  }

  /// Buyer or seller marks the trade completed on campus.
  /// Also sets the listing status to 'sold' in Firestore.
  Future<void> completeOrder(OrderModel order) async {
    final batch = _firestore.batch();

    // 1. Update order status to completed
    batch.update(_ordersRef.doc(order.id), {
      'status': 'completed',
      'updatedAt': Timestamp.now(),
    });

    // 2. Mark listing as sold
    batch.update(_listingsRef.doc(order.listingId), {
      'status': 'sold',
    });

    await batch.commit();
  }

  /// Cancel an order.
  Future<void> cancelOrder(OrderModel order) async {
    await _ordersRef.doc(order.id).update({
      'status': 'cancelled',
      'updatedAt': Timestamp.now(),
    });
  }

  /// Record an Ethiopian payment confirmation transaction reference (Telebirr/CBE SMS code).
  Future<void> updateOrderPaymentRef(String orderId, String transactionRef) async {
    await _ordersRef.doc(orderId).update({
      'transactionRef': transactionRef.trim(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Buyer submits payment proof (Telebirr / CBE Transaction ID and optional receipt photo).
  Future<void> submitPaymentProof({
    required OrderModel order,
    required String transactionRef,
    String? proofImage,
  }) async {
    final Map<String, dynamic> updates = {
      'transactionRef': transactionRef.trim(),
      'paymentStatus': 'proof_submitted',
      'disputeReason': null,
      'paidAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
    if (proofImage != null && proofImage.isNotEmpty) {
      updates['paymentProofImage'] = proofImage;
    }

    await _ordersRef.doc(order.id).update(updates);

    // Notify seller via email
    if (order.sellerEmail.isNotEmpty) {
      EmailService.sendAutomatedEmailNotification(
        toEmail: order.sellerEmail,
        toName: order.sellerName,
        fromName: order.buyerName,
        subject: '[CampusConnect] Payment Proof Submitted for "${order.listingTitle}"',
        message: 'Hi ${order.sellerName},\n\n'
            '${order.buyerName} submitted payment proof for "${order.listingTitle}".\n'
            'Method: ${order.paymentMethod}\n'
            'Transaction Ref: ${transactionRef.trim()}\n\n'
            'Please check your Telebirr (127) or CBE SMS to confirm you received ETB ${order.listingPrice.toStringAsFixed(2)}.\n'
            'Open the CampusConnect app on your phone to verify the payment!',
      ).catchError((e) => false);
    }
  }

  /// Seller verifies that the Telebirr/CBE SMS arrived and confirms payment.
  Future<void> verifyPayment(OrderModel order) async {
    await _ordersRef.doc(order.id).update({
      'paymentStatus': 'verified',
      'verifiedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // Notify buyer via email
    if (order.buyerEmail.isNotEmpty) {
      EmailService.sendAutomatedEmailNotification(
        toEmail: order.buyerEmail,
        toName: order.buyerName,
        fromName: order.sellerName,
        subject: '[CampusConnect] Payment Verified for "${order.listingTitle}"',
        message: 'Hi ${order.buyerName},\n\n'
            'Great news! ${order.sellerName} verified and confirmed your payment of ETB ${order.listingPrice.toStringAsFixed(2)}.\n\n'
            'Meetup Location: ${order.meetupLocation}\n'
            'Meetup Time: ${order.meetupTime}\n\n'
            'See you on campus to collect your item!',
      ).catchError((e) => false);
    }
  }

  /// Seller reports payment was not received (e.g. incorrect reference or no SMS arrived).
  Future<void> disputePayment(OrderModel order, {String? reason}) async {
    final finalReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Payment not found in SMS or bank account';

    await _ordersRef.doc(order.id).update({
      'paymentStatus': 'disputed',
      'disputeReason': finalReason,
      'updatedAt': Timestamp.now(),
    });

    if (order.buyerEmail.isNotEmpty) {
      EmailService.sendAutomatedEmailNotification(
        toEmail: order.buyerEmail,
        toName: order.buyerName,
        fromName: order.sellerName,
        subject: '[CampusConnect] Payment Not Received: "${order.listingTitle}"',
        message: 'Hi ${order.buyerName},\n\n'
            '${order.sellerName} was unable to confirm your payment with the provided transaction reference (${order.transactionRef ?? "None"}).\n\n'
            'Seller Report: $finalReason\n\n'
            'Please double check your Telebirr (127) or CBE transaction message and submit the correct reference in the app.',
      ).catchError((e) => false);
    }
  }
}
