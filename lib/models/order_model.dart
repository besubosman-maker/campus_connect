import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String listingId;
  final String listingTitle;
  final double listingPrice;
  final String? listingImage;
  final String sellerId;
  final String sellerName;
  final String sellerEmail;
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final String meetupLocation;
  final String meetupTime;
  final String? buyerNote;
  final String paymentMethod; // e.g. 'Telebirr (ቴሌብር)', 'CBE / CBE Birr', 'Cash on Meetup'
  final String? paymentDetails; // seller's telebirr number or CBE account
  final String? transactionRef; // Telebirr or CBE confirmation SMS reference
  final String paymentStatus; // 'unpaid', 'proof_submitted', 'verified', 'disputed'
  final String? disputeReason; // Seller's report reason when payment is disputed
  final String? paymentProofImage; // screenshot of Telebirr/CBE SMS
  final DateTime? paidAt;
  final DateTime? verifiedAt;
  final String status; // 'pending', 'accepted', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingPrice,
    this.listingImage,
    required this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    required this.meetupLocation,
    required this.meetupTime,
    this.buyerNote,
    this.paymentMethod = 'Telebirr (ቴሌብር)',
    this.paymentDetails,
    this.transactionRef,
    this.paymentStatus = 'unpaid',
    this.disputeReason,
    this.paymentProofImage,
    this.paidAt,
    this.verifiedAt,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isPaymentVerified => paymentStatus == 'verified';
  bool get isPaymentProofSubmitted => paymentStatus == 'proof_submitted';
  bool get isPaymentDisputed => paymentStatus == 'disputed';

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return OrderModel(
      id: doc.id,
      listingId: data['listingId'] as String? ?? '',
      listingTitle: data['listingTitle'] as String? ?? 'Campus Item',
      listingPrice: (data['listingPrice'] as num?)?.toDouble() ?? 0.0,
      listingImage: data['listingImage'] as String?,
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? 'Campus Seller',
      sellerEmail: data['sellerEmail'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'Campus Buyer',
      buyerEmail: data['buyerEmail'] as String? ?? '',
      meetupLocation: data['meetupLocation'] as String? ?? 'Campus Library',
      meetupTime: data['meetupTime'] as String? ?? 'Flexible',
      buyerNote: data['buyerNote'] as String?,
      paymentMethod: data['paymentMethod'] as String? ?? 'Telebirr (ቴሌብር)',
      paymentDetails: data['paymentDetails'] as String?,
      transactionRef: data['transactionRef'] as String?,
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      disputeReason: data['disputeReason'] as String?,
      paymentProofImage: data['paymentProofImage'] as String?,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'pending',
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
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerEmail': sellerEmail,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'meetupLocation': meetupLocation,
      'meetupTime': meetupTime,
      'buyerNote': buyerNote,
      'paymentMethod': paymentMethod,
      'paymentDetails': paymentDetails,
      'transactionRef': transactionRef,
      'paymentStatus': paymentStatus,
      'disputeReason': disputeReason,
      'paymentProofImage': paymentProofImage,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    double? listingPrice,
    String? listingImage,
    String? sellerId,
    String? sellerName,
    String? sellerEmail,
    String? buyerId,
    String? buyerName,
    String? buyerEmail,
    String? meetupLocation,
    String? meetupTime,
    String? buyerNote,
    String? paymentMethod,
    String? paymentDetails,
    String? transactionRef,
    String? paymentStatus,
    String? disputeReason,
    String? paymentProofImage,
    DateTime? paidAt,
    DateTime? verifiedAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingPrice: listingPrice ?? this.listingPrice,
      listingImage: listingImage ?? this.listingImage,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerEmail: sellerEmail ?? this.sellerEmail,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      meetupLocation: meetupLocation ?? this.meetupLocation,
      meetupTime: meetupTime ?? this.meetupTime,
      buyerNote: buyerNote ?? this.buyerNote,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      transactionRef: transactionRef ?? this.transactionRef,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      disputeReason: disputeReason ?? this.disputeReason,
      paymentProofImage: paymentProofImage ?? this.paymentProofImage,
      paidAt: paidAt ?? this.paidAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
