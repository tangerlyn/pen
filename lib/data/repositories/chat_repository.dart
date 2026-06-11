import '../models/chat_model.dart';
import '../../core/constants/app_constants.dart';

/// 더미 채팅 레포지토리
class ChatRepository {
  static final List<ChatRoom> _dummyChatRooms = [
    ChatRoom(
      id: 'chat_001',
      listingId: 'listing_001',
      buyerId: 'dummy_user_001',
      sellerId: 'user_002',
      lastMessage: '혹시 직거래 가능한가요?',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 30)),
      unreadCount: {'dummy_user_001': 1, 'user_002': 0},
    ),
    ChatRoom(
      id: 'chat_002',
      listingId: 'listing_003',
      buyerId: 'user_005',
      sellerId: 'dummy_user_001',
      lastMessage: '네, 내일 오후에 가능해요!',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: {'user_005': 0, 'dummy_user_001': 0},
    ),
  ];

  static final Map<String, List<ChatMessage>> _dummyMessages = {
    'chat_001': [
      ChatMessage(id: 'msg_001', senderId: 'user_002', content: '안녕하세요! 판매글 보고 연락드려요.', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
      ChatMessage(id: 'msg_002', senderId: 'dummy_user_001', content: '네, 안녕하세요! 문의 주셔서 감사해요.', createdAt: DateTime.now().subtract(const Duration(minutes: 55))),
      ChatMessage(id: 'msg_003', senderId: 'user_002', content: '혹시 직거래 가능한가요?', createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
    ],
    'chat_002': [
      ChatMessage(id: 'msg_011', senderId: 'user_005', content: '안녕하세요, 라미 사파리 아직 있나요?', createdAt: DateTime.now().subtract(const Duration(hours: 3))),
      ChatMessage(id: 'msg_012', senderId: 'dummy_user_001', content: '네, 아직 있어요!', createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45))),
      ChatMessage(id: 'msg_013', senderId: 'user_005', content: '내일 직거래 가능할까요?', createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 10))),
      ChatMessage(id: 'msg_014', senderId: 'dummy_user_001', content: '네, 내일 오후에 가능해요!', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    ],
  };

  Future<String> getOrCreateChatRoom({
    required String listingId,
    required String buyerId,
    required String sellerId,
  }) async {
    final existing = _dummyChatRooms.where((r) =>
        r.listingId == listingId && r.buyerId == buyerId && r.sellerId == sellerId).firstOrNull;
    if (existing != null) return existing.id;

    final newRoom = ChatRoom(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
      unreadCount: {buyerId: 0, sellerId: 0},
    );
    _dummyChatRooms.add(newRoom);
    return newRoom.id;
  }

  Stream<List<ChatRoom>> watchChatRooms(String uid) {
    final rooms = _dummyChatRooms
        .where((r) => r.buyerId == uid || r.sellerId == uid)
        .toList()
      ..sort((a, b) => (b.lastMessageAt ?? DateTime(2000)).compareTo(a.lastMessageAt ?? DateTime(2000)));
    return Stream.value(rooms);
  }

  Stream<ChatRoom?> watchChatRoom(String chatId) {
    return Stream.value(_dummyChatRooms.where((r) => r.id == chatId).firstOrNull);
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return Stream.value(_dummyMessages[chatId] ?? []);
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      type: type,
      content: content,
      createdAt: DateTime.now(),
    );
    _dummyMessages.putIfAbsent(chatId, () => []).add(msg);

    final roomIdx = _dummyChatRooms.indexWhere((r) => r.id == chatId);
    if (roomIdx >= 0) {
      final room = _dummyChatRooms[roomIdx];
      _dummyChatRooms[roomIdx] = room.copyWith(
        lastMessage: type == MessageType.image ? '[사진]' : content,
        lastMessageAt: DateTime.now(),
      );
    }
  }

  Future<void> markAsRead(String chatId, String uid) async {}

  Future<int> getTotalUnread(String uid) async {
    return _dummyChatRooms
        .where((r) => r.buyerId == uid || r.sellerId == uid)
        .fold<int>(0, (sum, r) => sum + r.unreadFor(uid));
  }

  bool containsDangerousPattern(String text) {
    return AppConstants.phonePattern.hasMatch(text) ||
        AppConstants.accountPattern.hasMatch(text);
  }
}
