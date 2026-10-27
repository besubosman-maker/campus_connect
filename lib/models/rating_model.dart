import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String listingId;
  final double stars;
  final String comment;
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.listingId,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return RatingModel(
      id: doc.id,
      fromUserId: data['fromUserId'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      listingId: data['listingId'] as String? ?? '',
      stars: (data['stars'] as num?)?.toDouble() ?? 5.0,
      comment: data['comment'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'listingId': listingId,
      'stars': stars,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
