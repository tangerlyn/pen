import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_model.dart';
import '../../../shared/providers/providers.dart';

final chatRoomsProvider = StreamProviderFamily<List<ChatRoom>, String>((ref, uid) {
  return ref.watch(chatRepoProvider).watchChatRooms(uid);
});

final chatMessagesProvider = StreamProviderFamily<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepoProvider).watchMessages(chatId);
});

final chatRoomProvider = StreamProviderFamily<ChatRoom?, String>((ref, chatId) {
  return ref.watch(chatRepoProvider).watchChatRoom(chatId);
});
