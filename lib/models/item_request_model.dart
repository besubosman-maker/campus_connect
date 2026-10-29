import 'package:cloud_firestore/cloud_firestore.dart';

class ItemRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userEmail;
  final String title;
  final String description;
  final String category;
  final double budgetETB;
  final String campusLocation;
  final String? contactPhone;
  final String? contactTelegram;
  final String status; // 'open', 'fulfilled'
  final DateTime createdAt;

  ItemRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.userEmail,
    required this.title,
    required this.description,
    required this.category,
    required this.budgetETB,
    required this.campusLocation,
    this.contactPhone,
    this.contactTelegram,
    this.status = 'open',
    required this.createdAt,
  });

  bool get isOpen => status == 'open';

  factory ItemRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return ItemRequestModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Campus Student',
      userAvatar: map['userAvatar'],
      userEmail: map['userEmail'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      budgetETB: (map['budgetETB'] as num?)?.toDouble() ?? 0.0,
      campusLocation: map['campusLocation'] ?? 'Main Campus',
      contactPhone: map['contactPhone'],
      contactTelegram: map['contactTelegram'],
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userEmail': userEmail,
      'title': title,
      'description': description,
      'category': category,
      'budgetETB': budgetETB,
      'campusLocation': campusLocation,
      'contactPhone': contactPhone,
      'contactTelegram': contactTelegram,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
