import 'package:cloud_firestore/cloud_firestore.dart';

class ListingQuestionModel {
  final String id;
  final String listingId;
  final String askerId;
  final String askerName;
  final String question;
  final String? answer;
  final String sellerId;
  final int upvotes;
  final List<String> upvotedUserIds;
  final DateTime createdAt;
  final DateTime? answeredAt;

  ListingQuestionModel({
    required this.id,
    required this.listingId,
    required this.askerId,
    required this.askerName,
    required this.question,
    this.answer,
    required this.sellerId,
    this.upvotes = 0,
    this.upvotedUserIds = const [],
    required this.createdAt,
    this.answeredAt,
  });

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  factory ListingQuestionModel.fromMap(Map<String, dynamic> map, String docId) {
    return ListingQuestionModel(
      id: docId,
      listingId: map['listingId'] ?? '',
      askerId: map['askerId'] ?? '',
      askerName: map['askerName'] ?? 'Student',
      question: map['question'] ?? '',
      answer: map['answer'],
      sellerId: map['sellerId'] ?? '',
      upvotes: (map['upvotes'] as num?)?.toInt() ?? 0,
      upvotedUserIds: List<String>.from(map['upvotedUserIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      answeredAt: map['answeredAt'] != null
          ? (map['answeredAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'askerId': askerId,
      'askerName': askerName,
      'question': question,
      'answer': answer,
      'sellerId': sellerId,
      'upvotes': upvotes,
      'upvotedUserIds': upvotedUserIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
    };
  }
}
