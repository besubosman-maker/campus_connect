import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/listing_model.dart';
import 'cloud_image_service.dart';

class ListingService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference get _listingsRef => _firestore.collection('listings');

  /// Fetch paginated listings with optional category filter and keyword search.
  Future<QuerySnapshot> getListingsQuery({
    String? category,
    String? searchQuery,
    DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    try {
      Query query = _listingsRef.where('status', isEqualTo: 'available');

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim().toLowerCase();
        query = query.where('searchKeywords', arrayContains: term);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      return await query.limit(limit).get();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Fallback: If composite index is still building in Firebase console, query simply without compound index requirement
        debugPrint('Composite index building or not created, using fallback: $e');
        Query fallback = _listingsRef;
        if (startAfterDoc != null) {
          fallback = fallback.startAfterDocument(startAfterDoc);
        }
        return await fallback.limit(limit).get();
      }
      rethrow;
    }
  }

  /// Real-time stream of listings for real-time reactivity on browse screen.
  Stream<List<ListingModel>> getListingsStream({
    String? category,
    int limit = 20,
  }) {
    Query query = _listingsRef;

    if (category != null && category.isNotEmpty && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ListingModel.fromFirestore(doc))
          .where((item) => item.isAvailable)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream of listings created by a specific student seller.
  Stream<List<ListingModel>> getUserListingsStream(String userId) {
    return _listingsRef
        .where('sellerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ListingModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Fetch a single listing by its ID.
  Future<ListingModel?> getListingById(String id) async {
    try {
      final doc = await _listingsRef.doc(id).get();
      if (doc.exists) {
        return ListingModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting listing: $e');
      return null;
    }
  }

  /// Helper to upload an image to real cloud hosting (ImgBB) or Firebase Storage,
  /// with automatic fallback to Base64 data URI if offline.
  Future<String> _uploadImageToStorage({
    required String path,
    required XFile file,
  }) async {
    // 1. Upload to free real cloud hosting (ImgBB) for permanent public CDN URL
    try {
      final cloudUrl = await CloudImageService.uploadImage(file);
      if (cloudUrl.startsWith('http://') || cloudUrl.startsWith('https://')) {
        return cloudUrl;
      }
    } catch (e) {
      debugPrint('CloudImageService attempt notice: $e');
    }

    // 2. Try Firebase Storage if active
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    try {
      final storageRef = _storage.ref().child(path);
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await storageRef.putData(bytes, metadata);
      } else {
        await storageRef.putFile(File(file.path), metadata);
      }
      return await storageRef.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' || e.code == 'bucket-not-found') {
        try {
          final isAppspot = _storage.bucket.contains('appspot.com');
          final fallbackBucket = isAppspot
              ? 'campusconnect-486c9.firebasestorage.app'
              : 'campusconnect-486c9.appspot.com';
          final fallbackStorage = FirebaseStorage.instanceFor(bucket: fallbackBucket);
          final altRef = fallbackStorage.ref().child(path);
          if (kIsWeb) {
            final bytes = await file.readAsBytes();
            await altRef.putData(bytes, metadata);
          } else {
            await altRef.putFile(File(file.path), metadata);
          }
          return await altRef.getDownloadURL();
        } catch (_) {}
      }
    } catch (_) {}

    // 3. Fallback: Base64 Data URI in Firestore
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Create a new listing with uploaded images and generated search keywords.
  Future<ListingModel> createListing({
    required String sellerId,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<XFile> imageFiles,
  }) async {
    final docRef = _listingsRef.doc();
    final listingId = docRef.id;

    // Upload images to Firebase Storage
    final List<String> imageUrls = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final fileId = _uuid.v4();
      final url = await _uploadImageToStorage(
        path: 'listings/$listingId/$fileId.jpg',
        file: file,
      );
      imageUrls.add(url);
    }

    final searchKeywords = ListingModel.generateKeywords(title, category);

    final newListing = ListingModel(
      id: listingId,
      sellerId: sellerId,
      title: title.trim(),
      description: description.trim(),
      price: price,
      category: category,
      images: imageUrls,
      status: 'available',
      createdAt: DateTime.now(),
      searchKeywords: searchKeywords,
    );

    await docRef.set(newListing.toMap());
    return newListing;
  }

  /// Update an existing listing.
  Future<void> updateListing({
    required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> images,
    List<XFile>? newImageFiles,
  }) async {
    List<String> finalImages = List<String>.from(images);

    // Upload any newly picked images
    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      for (final file in newImageFiles) {
        final fileId = _uuid.v4();
        final url = await _uploadImageToStorage(
          path: 'listings/$id/$fileId.jpg',
          file: file,
        );
        finalImages.add(url);
      }
    }

    final searchKeywords = ListingModel.generateKeywords(title, category);

    await _listingsRef.doc(id).update({
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'category': category,
      'images': finalImages,
      'searchKeywords': searchKeywords,
    });
  }

  /// Update status of a listing (e.g. 'available' or 'sold').
  Future<void> updateListingStatus(String listingId, String status) async {
    await _listingsRef.doc(listingId).update({
      'status': status,
    });
  }

  /// Delete a listing and its corresponding storage images.
  Future<void> deleteListing(String listingId, List<String> imageUrls) async {
    // Delete Firestore document
    await _listingsRef.doc(listingId).delete();

    // Delete image files from Storage
    for (final url in imageUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint('Failed to delete storage file $url: $e');
      }
    }
  }
}
