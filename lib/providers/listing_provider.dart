import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/listing_model.dart';
import '../services/listing_service.dart';

class ListingProvider extends ChangeNotifier {
  final ListingService _listingService = ListingService();

  List<ListingModel> _listings = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;

  static const int pageSize = 20;

  List<ListingModel> get listings => _listings;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  ListingProvider() {
    if (Firebase.apps.isNotEmpty) {
      fetchInitialListings();
    }
  }

  Future<void> fetchInitialListings() async {
    _isLoading = true;
    _errorMessage = null;
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();

    try {
      final snapshot = await _listingService.getListingsQuery(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        startAfterDoc: null,
        limit: pageSize,
      );

      final items = snapshot.docs
          .map((doc) => ListingModel.fromFirestore(doc))
          .where((item) {
            if (!item.isAvailable) return false;
            if (_selectedCategory != 'All' && item.category != _selectedCategory) {
              return false;
            }
            return true;
          })
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _listings = items;

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= pageSize;
    } catch (e) {
      _errorMessage = 'Failed to load listings: ${e.toString()}';
      _listings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreListings() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _listingService.getListingsQuery(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        startAfterDoc: _lastDocument,
        limit: pageSize,
      );

      final newItems = snapshot.docs
          .map((doc) => ListingModel.fromFirestore(doc))
          .where((item) {
            if (!item.isAvailable) return false;
            if (_selectedCategory != 'All' && item.category != _selectedCategory) {
              return false;
            }
            return true;
          })
          .toList();
      newItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _listings.addAll(newItems);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= pageSize;
    } catch (e) {
      debugPrint('Error loading more listings: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    fetchInitialListings();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchInitialListings();
  }

  Future<void> refresh() async {
    await fetchInitialListings();
  }

  Future<bool> createListing({
    required String sellerId,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<XFile> images,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newListing = await _listingService.createListing(
        sellerId: sellerId,
        title: title,
        description: description,
        price: price,
        category: category,
        imageFiles: images,
      );
      _listings.insert(0, newListing);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create listing: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateListing({
    required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> images,
    List<XFile>? newImages,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _listingService.updateListing(
        id: id,
        title: title,
        description: description,
        price: price,
        category: category,
        images: images,
        newImageFiles: newImages,
      );
      await fetchInitialListings();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update listing: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsSold(String listingId) async {
    try {
      await _listingService.updateListingStatus(listingId, 'sold');
      // Update local item
      final index = _listings.indexWhere((item) => item.id == listingId);
      if (index != -1) {
        _listings[index] = _listings[index].copyWith(status: 'sold');
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteListing(String listingId, List<String> imageUrls) async {
    try {
      await _listingService.deleteListing(listingId, imageUrls);
      _listings.removeWhere((item) => item.id == listingId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete listing: $e';
      notifyListeners();
      return false;
    }
  }
}
