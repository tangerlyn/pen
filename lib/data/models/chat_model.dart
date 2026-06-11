class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = const {},
  });

  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  factory ChatRoom.fromMap(Map<String, dynamic> data, String id) {
    return ChatRoom(
      id: id,
      listingId: data['listingId'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: data['lastMessageAt'] as DateTime?,
      unreadCount: Map<String, int>.from(data['unreadCount'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'listingId': listingId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt,
        'unreadCount': unreadCount,
      };

  ChatRoom copyWith({
    String? id, String? listingId, String? buyerId, String? sellerId,
    String? lastMessage, DateTime? lastMessageAt, Map<String, int>? unreadCount,
  }) {
    return ChatRoom(
      id: id ?? this.id, listingId: listingId ?? this.listingId,
      buyerId: buyerId ?? this.buyerId, sellerId: sellerId ?? this.sellerId,
      lastMessage: lastMessage ?? this.lastMessage, lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

enum MessageType { text, image }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    this.type = MessageType.text,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String content;
  final DateTime createdAt;

  bool get isImage => type == MessageType.image;

  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'type': type.name,
        'content': content,
        'createdAt': createdAt,
      };
}
