import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String listingId;
  final String listingTitle;
  final double listingPrice;
  final String? listingImage;
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final String sellerId;
  final String sellerName;
  final double offerAmount;
  final double? counterAmount;
  final String status; // 'pending', 'accepted', 'declined', 'countered', 'completed'
  final String? buyerNote;
  final String? sellerNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  OfferModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingPrice,
    this.listingImage,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    required this.sellerId,
    required this.sellerName,
    required this.offerAmount,
    this.counterAmount,
    this.status = 'pending',
    this.buyerNote,
    this.sellerNote,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCountered => status == 'countered';

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return OfferModel(
      id: doc.id,
      listingId: data['listingId'] as String? ?? '',
      listingTitle: data['listingTitle'] as String? ?? '',
      listingPrice: (data['listingPrice'] as num?)?.toDouble() ?? 0.0,
      listingImage: data['listingImage'] as String?,
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'Buyer',
      buyerEmail: data['buyerEmail'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? 'Seller',
      offerAmount: (data['offerAmount'] as num?)?.toDouble() ?? 0.0,
      counterAmount: (data['counterAmount'] as num?)?.toDouble(),
      status: data['status'] as String? ?? 'pending',
      buyerNote: data['buyerNote'] as String?,
      sellerNote: data['sellerNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingPrice': listingPrice,
      'listingImage': listingImage,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'offerAmount': offerAmount,
      'counterAmount': counterAmount,
      'status': status,
      'buyerNote': buyerNote,
      'sellerNote': sellerNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OfferModel copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    double? listingPrice,
    String? listingImage,
    String? buyerId,
    String? buyerName,
    String? buyerEmail,
    String? sellerId,
    String? sellerName,
    double? offerAmount,
    double? counterAmount,
    String? status,
    String? buyerNote,
    String? sellerNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingPrice: listingPrice ?? this.listingPrice,
      listingImage: listingImage ?? this.listingImage,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      offerAmount: offerAmount ?? this.offerAmount,
      counterAmount: counterAmount ?? this.counterAmount,
      status: status ?? this.status,
      buyerNote: buyerNote ?? this.buyerNote,
      sellerNote: sellerNote ?? this.sellerNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
