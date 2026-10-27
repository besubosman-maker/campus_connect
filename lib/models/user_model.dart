import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final double rating;
  final int ratingCount;
  final DateTime joinedAt;
  final String? fcmToken;
  // Ethiopian Payment and Contact info
  final String? phoneNumber;
  final String? telebirrNumber;
  final String? cbeAccount;
  final String? cbeAccountName;
  final String? preferredPayment;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.rating = 0.0,
    this.ratingCount = 0,
    required this.joinedAt,
    this.fcmToken,
    this.phoneNumber,
    this.telebirrNumber,
    this.cbeAccount,
    this.cbeAccountName,
    this.preferredPayment,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? 'Campus Student',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: data['fcmToken'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      telebirrNumber: data['telebirrNumber'] as String?,
      cbeAccount: data['cbeAccount'] as String?,
      cbeAccountName: data['cbeAccountName'] as String?,
      preferredPayment: data['preferredPayment'] as String?,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name'] as String? ?? 'Campus Student',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: map['fcmToken'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      telebirrNumber: map['telebirrNumber'] as String?,
      cbeAccount: map['cbeAccount'] as String?,
      cbeAccountName: map['cbeAccountName'] as String?,
      preferredPayment: map['preferredPayment'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'rating': rating,
      'ratingCount': ratingCount,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'fcmToken': fcmToken,
      'phoneNumber': phoneNumber,
      'telebirrNumber': telebirrNumber,
      'cbeAccount': cbeAccount,
      'cbeAccountName': cbeAccountName,
      'preferredPayment': preferredPayment,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    double? rating,
    int? ratingCount,
    DateTime? joinedAt,
    String? fcmToken,
    String? phoneNumber,
    String? telebirrNumber,
    String? cbeAccount,
    String? cbeAccountName,
    String? preferredPayment,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      joinedAt: joinedAt ?? this.joinedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      telebirrNumber: telebirrNumber ?? this.telebirrNumber,
      cbeAccount: cbeAccount ?? this.cbeAccount,
      cbeAccountName: cbeAccountName ?? this.cbeAccountName,
      preferredPayment: preferredPayment ?? this.preferredPayment,
    );
  }
}
