import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _reportsRef => _firestore.collection('reports');

  // Submit a new flag / report
  Future<void> submitReport({
    required String reporterId,
    required String reporterName,
    required String targetType, // 'listing' or 'user'
    required String targetId,
    required String targetTitle,
    required String reason,
    required String details,
  }) async {
    final docRef = _reportsRef.doc();
    final report = ReportModel(
      id: docRef.id,
      reporterId: reporterId,
      reporterName: reporterName,
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      reason: reason,
      details: details,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    await docRef.set(report.toMap());
  }

  // Stream of pending reports for Super Admin
  Stream<List<ReportModel>> getReportsStream({String status = 'pending'}) {
    return _reportsRef
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .where((r) => status == 'all' || r.status == status)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Update report status (e.g. 'resolved', 'dismissed')
  Future<void> updateReportStatus(String reportId, String status) async {
    await _reportsRef.doc(reportId).update({'status': status});
  }
}
