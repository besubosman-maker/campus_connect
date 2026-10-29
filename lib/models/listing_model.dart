import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final String status; // 'available' or 'sold'
  final DateTime createdAt;
  final List<String> searchKeywords;
  // Monetization & Contact features
  final bool isFeatured;
  final DateTime? featuredUntil;
  final String? sellerTelegram;
  final String? sellerPhone;

  ListingModel({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    this.status = 'available',
    required this.createdAt,
    required this.searchKeywords,
    this.isFeatured = false,
    this.featuredUntil,
    this.sellerTelegram,
    this.sellerPhone,
  });

  bool get isAvailable => status == 'available';
  bool get isSold => status == 'sold';
  bool get isBoostedActive =>
      isFeatured && (featuredUntil == null || featuredUntil!.isAfter(DateTime.now()));

  static List<String> generateKeywords(String title, String category) {
    final Set<String> keywords = {};
    final words = '$title $category'.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      if (clean.isNotEmpty) {
        keywords.add(clean);
        for (int i = 1; i <= clean.length; i++) {
          keywords.add(clean.substring(0, i));
        }
      }
    }
    return keywords.toList();
  }

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ListingModel(
      id: doc.id,
      sellerId: data['sellerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] as String? ?? 'General',
      images: List<String>.from(data['images'] as List? ?? []),
      status: data['status'] as String? ?? 'available',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      searchKeywords: List<String>.from(data['searchKeywords'] as List? ?? []),
      isFeatured: data['isFeatured'] as bool? ?? false,
      featuredUntil: (data['featuredUntil'] as Timestamp?)?.toDate(),
      sellerTelegram: data['sellerTelegram'] as String?,
      sellerPhone: data['sellerPhone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'searchKeywords': searchKeywords.isNotEmpty
          ? searchKeywords
          : generateKeywords(title, category),
      'isFeatured': isFeatured,
      'featuredUntil': featuredUntil != null ? Timestamp.fromDate(featuredUntil!) : null,
      'sellerTelegram': sellerTelegram,
      'sellerPhone': sellerPhone,
    };
  }

  ListingModel copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    String? status,
    DateTime? createdAt,
    List<String>? searchKeywords,
    bool? isFeatured,
    DateTime? featuredUntil,
    String? sellerTelegram,
    String? sellerPhone,
  }) {
    return ListingModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      sellerTelegram: sellerTelegram ?? this.sellerTelegram,
      sellerPhone: sellerPhone ?? this.sellerPhone,
    );
  }
}
