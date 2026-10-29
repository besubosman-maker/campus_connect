import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer_model.dart';

class OfferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _offersRef => _firestore.collection('offers');

  // Submit a Bargain Offer
  Future<String> submitOffer(OfferModel offer) async {
    final docRef = _offersRef.doc();
    final newOffer = offer.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(newOffer.toMap());
    return docRef.id;
  }

  // Stream Offers where User is Buyer
  Stream<List<OfferModel>> getBuyerOffersStream(String buyerId) {
    return _offersRef
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OfferModel.fromFirestore(doc)).toList());
  }

  // Stream Offers where User is Seller
  Stream<List<OfferModel>> getSellerOffersStream(String sellerId) {
    return _offersRef
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OfferModel.fromFirestore(doc)).toList());
  }

  // Accept, Decline, or Counter-Offer
  Future<void> respondToOffer({
    required String offerId,
    required String action, // 'accept', 'decline', 'counter'
    double? counterAmount,
    String? sellerNote,
  }) async {
    final Map<String, dynamic> updates = {
      'status': action == 'accept'
          ? 'accepted'
          : action == 'counter'
              ? 'countered'
              : 'declined',
      'updatedAt': Timestamp.now(),
    };

    if (counterAmount != null) updates['counterAmount'] = counterAmount;
    if (sellerNote != null) updates['sellerNote'] = sellerNote;

    await _offersRef.doc(offerId).update(updates);
  }
}
