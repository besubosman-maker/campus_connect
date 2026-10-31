import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String targetType; // 'listing' or 'user'
  final String targetId;
  final String targetTitle;
  final String reason;
  final String details;
  final DateTime createdAt;
  final String status; // 'pending', 'resolved', 'dismissed'

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'targetType': targetType,
      'targetId': targetId,
      'targetTitle': targetTitle,
      'reason': reason,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? 'Anonymous Member',
      targetType: data['targetType'] ?? 'listing',
      targetId: data['targetId'] ?? '',
      targetTitle: data['targetTitle'] ?? '',
      reason: data['reason'] ?? 'Suspicious Activity',
      details: data['details'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
