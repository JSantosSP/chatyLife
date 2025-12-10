class ChatModel {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount1;
  final int unreadCount2;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant1Id': participant1Id,
      'participant2Id': participant2Id,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount1': unreadCount1,
      'unreadCount2': unreadCount2,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      participant1Id: map['participant1Id'] ?? '',
      participant2Id: map['participant2Id'] ?? '',
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.parse(map['lastMessageTime'])
          : null,
      unreadCount1: map['unreadCount1'] ?? 0,
      unreadCount2: map['unreadCount2'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  String getOtherParticipantId(String currentUserId) {
    return participant1Id == currentUserId ? participant2Id : participant1Id;
  }

  int getUnreadCount(String currentUserId) {
    return participant1Id == currentUserId ? unreadCount1 : unreadCount2;
  }
}



