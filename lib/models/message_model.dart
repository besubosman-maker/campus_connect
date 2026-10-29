import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool read;
  final String type; // 'text', 'image', 'voice'
  final String? mediaUrl;
  final int? durationSeconds;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.read = false,
    this.type = 'text',
    this.mediaUrl,
    this.durationSeconds,
  });

  bool get isImage => type == 'image';
  bool get isVoice => type == 'voice';

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      type: data['type'] as String? ?? 'text',
      mediaUrl: data['mediaUrl'] as String?,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'read': read,
      'type': type,
      'mediaUrl': mediaUrl,
      'durationSeconds': durationSeconds,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? sentAt,
    bool? read,
    String? type,
    String? mediaUrl,
    int? durationSeconds,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
