import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_request_model.dart';

class ItemRequestService {
  final CollectionReference _requestsRef =
      FirebaseFirestore.instance.collection('item_requests');

  // Stream all active item requests
  Stream<List<ItemRequestModel>> getOpenRequestsStream({String? category}) {
    Query query = _requestsRef;
    if (category != null && category.isNotEmpty && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ItemRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      // Sort client-side by createdAt descending to avoid composite index requirement
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream user's own requests
  Stream<List<ItemRequestModel>> getUserRequestsStream(String userId) {
    return _requestsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ItemRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Create a new request
  Future<void> createRequest(ItemRequestModel request) async {
    final docRef = _requestsRef.doc();
    await docRef.set(request.toMap());
  }

  // Update status (e.g. mark fulfilled)
  Future<void> updateStatus(String requestId, String status) async {
    await _requestsRef.doc(requestId).update({
      'status': status,
    });
  }

  // Delete request
  Future<void> deleteRequest(String requestId) async {
    await _requestsRef.doc(requestId).delete();
  }
}
