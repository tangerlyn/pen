import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../shared/providers/providers.dart';
import '../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showDangerWarning = false;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      ref.read(chatRepoProvider).markAsRead(widget.chatId, uid);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final uid = ref.read(currentUidProvider);
    final room = ref.read(chatRoomProvider(widget.chatId)).value;
    if (uid == null || room == null) return;

    final hasDanger = ref.read(chatRepoProvider).containsDangerousPattern(text);
    if (hasDanger) {
      setState(() => _showDangerWarning = true);
    }

    final receiverId = uid == room.buyerId ? room.sellerId : room.buyerId;
    _controller.clear();
    await ref.read(chatRepoProvider).sendMessage(
          chatId: widget.chatId,
          senderId: uid,
          receiverId: receiverId,
          content: text.trim(),
        );
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final uid = ref.read(currentUidProvider);
    final room = ref.read(chatRoomProvider(widget.chatId)).value;
    if (uid == null || room == null) return;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    final url = await ref.read(storageServiceProvider).uploadChatImage(
          File(xfile.path),
          widget.chatId,
        );

    final receiverId = uid == room.buyerId ? room.sellerId : room.buyerId;
    await ref.read(chatRepoProvider).sendMessage(
          chatId: widget.chatId,
          senderId: uid,
          receiverId: receiverId,
          content: url,
          type: MessageType.image,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final room = ref.watch(chatRoomProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(
        title: room.when(
          loading: () => const Text(''),
          error: (_, __) => const Text('채팅'),
          data: (r) {
            if (r == null || uid == null) return const Text('채팅');
            final other = uid == r.buyerId ? r.sellerId : r.buyerId;
            return Text(other);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 위험 경고
          if (_showDangerWarning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.warning.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '채팅창 외부에서 계좌번호나 전화번호를 주고받는 것은 사기 위험이 있습니다.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _showDangerWarning = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // 메시지 리스트
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('메시지를 불러올 수 없습니다.')),
              data: (list) => ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _MessageBubble(
                  message: list[i],
                  isMe: list[i].senderId == uid,
                ),
              ),
            ),
          ),
          // 입력창
          Container(
            padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendImage,
                  icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _sendMessage(_controller.text),
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(radius: 16, backgroundColor: AppColors.chipBackground),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: message.isImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.chipBackground,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: message.isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: message.content,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
