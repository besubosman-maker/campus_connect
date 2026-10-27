import 'package:cloud_firestore/cloud_firestore.dart';

class ParticipantInfo {
  final String name;
  final String? photoUrl;

  ParticipantInfo({
    required this.name,
    this.photoUrl,
  });

  factory ParticipantInfo.fromMap(Map<String, dynamic> map) {
    return ParticipantInfo(
      name: map['name'] as String? ?? 'Campus User',
      photoUrl: map['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
    };
  }
}

class ChatModel {
  final String id;
  final List<String> members;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Map<String, ParticipantInfo> participants;
  final String? lastSenderId;
  final bool lastMessageRead;

  ChatModel({
    required this.id,
    required this.members,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.participants,
    this.lastSenderId,
    this.lastMessageRead = true,
  });

  bool hasUnread(String currentUserId) {
    return lastSenderId != null &&
        lastSenderId != currentUserId &&
        !lastMessageRead &&
        lastMessage.isNotEmpty;
  }

  static String getChatId(String uidA, String uidB) {
    final list = [uidA, uidB]..sort();
    return '${list[0]}_${list[1]}';
  }

  String getOtherUserId(String currentUserId) {
    return members.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  ParticipantInfo getOtherParticipant(String currentUserId) {
    final otherId = getOtherUserId(currentUserId);
    return participants[otherId] ?? ParticipantInfo(name: 'Campus User');
  }

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawParticipants = (data['participants'] as Map<String, dynamic>?) ?? {};
    final Map<String, ParticipantInfo> participantsMap = {};
    rawParticipants.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        participantsMap[key] = ParticipantInfo.fromMap(val);
      } else if (val is Map) {
        participantsMap[key] = ParticipantInfo.fromMap(Map<String, dynamic>.from(val));
      }
    });

    return ChatModel(
      id: doc.id,
      members: List<String>.from(data['members'] as List? ?? []),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: participantsMap,
      lastSenderId: data['lastSenderId'] as String?,
      lastMessageRead: data['lastMessageRead'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'members': members,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'participants': participants.map((key, value) => MapEntry(key, value.toMap())),
      'lastSenderId': lastSenderId,
      'lastMessageRead': lastMessageRead,
    };
  }
}
