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
  final String? telegramUsername;
  // Super Admin and Moderation fields
  final String role; // 'super_admin', 'admin', 'user'
  final bool isBanned;
  final bool isVerifiedSeller;
  // Kebele ID / Student ID verification
  final String idVerificationStatus; // 'unverified', 'pending', 'verified', 'rejected'
  final String? idDocumentUrl;
  // Wishlist / Favorites
  final List<String> favorites;

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
    this.telegramUsername,
    this.role = 'user',
    this.isBanned = false,
    this.isVerifiedSeller = false,
    this.idVerificationStatus = 'unverified',
    this.idDocumentUrl,
    this.favorites = const [],
  });

  bool get isSuperAdmin =>
      role == 'super_admin' ||
      email.toLowerCase().contains('admin') ||
      email.toLowerCase() == 'besubosman@gmail.com';

  bool get isAdmin => isSuperAdmin || role == 'admin';

  bool get isIdVerified => idVerificationStatus == 'verified';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? 'Community Member',
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
      telegramUsername: data['telegramUsername'] as String?,
      role: data['role'] as String? ?? 'user',
      isBanned: data['isBanned'] as bool? ?? false,
      isVerifiedSeller: data['isVerifiedSeller'] as bool? ?? false,
      idVerificationStatus: data['idVerificationStatus'] as String? ?? 'unverified',
      idDocumentUrl: data['idDocumentUrl'] as String?,
      favorites: List<String>.from(data['favorites'] as List? ?? []),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name'] as String? ?? 'Community Member',
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
      telegramUsername: map['telegramUsername'] as String?,
      role: map['role'] as String? ?? 'user',
      isBanned: map['isBanned'] as bool? ?? false,
      isVerifiedSeller: map['isVerifiedSeller'] as bool? ?? false,
      idVerificationStatus: map['idVerificationStatus'] as String? ?? 'unverified',
      idDocumentUrl: map['idDocumentUrl'] as String?,
      favorites: List<String>.from(map['favorites'] as List? ?? []),
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
      'telegramUsername': telegramUsername,
      'role': role,
      'isBanned': isBanned,
      'isVerifiedSeller': isVerifiedSeller,
      'idVerificationStatus': idVerificationStatus,
      'idDocumentUrl': idDocumentUrl,
      'favorites': favorites,
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
    String? telegramUsername,
    String? role,
    bool? isBanned,
    bool? isVerifiedSeller,
    String? idVerificationStatus,
    String? idDocumentUrl,
    List<String>? favorites,
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
      telegramUsername: telegramUsername ?? this.telegramUsername,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      isVerifiedSeller: isVerifiedSeller ?? this.isVerifiedSeller,
      idVerificationStatus: idVerificationStatus ?? this.idVerificationStatus,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      favorites: favorites ?? this.favorites,
    );
  }
}
